import gleam/option.{type Option, Some}
import gleam/result
import gleam/io
import gleam/list
import gleam/erlang/process.{type Subject}
import gleam/regex
import gleam/json.{array, object, string}
import nerf/websocket.{type Connection}
import nerf/gun.{Text}
import glome/core/authentication
import glome/core/loops
import glome/core/util
import glome/core/error.{type GlomeError, LoopNil}
import glome/homeassistant/state.{type State}
import glome/homeassistant/state_change_event.{type StateChangeEvent}
import glome/homeassistant/entity_id.{type EntityId}
import glome/homeassistant/entity_selector.{
  type EntitySelector, All, ObjectId, Regex,
}
import glome/homeassistant/domain.{type Domain}
import glome/homeassistant/environment.{type Configuration}
import glome/homeassistant/service.{
  type Service, type Target, Area, Device, Entity,
}

pub opaque type HomeAssistant {
  HomeAssistant(handlers: StateChangeHandlers, config: Configuration)
}

// PUBLIC API
pub type StateChangeHandler =
  fn(StateChangeEvent, HomeAssistant) -> Result(Nil, GlomeError)

pub type StateChangeFilter =
  fn(StateChangeEvent, HomeAssistant) -> Bool

pub type StateChangeHandlersEntry {
  StateChangeHandlersEntry(
    entity_selector: EntitySelector,
    handler: StateChangeHandler,
    filter: StateChangeFilter,
  )
}

pub type StateChangeHandlers =
  List(StateChangeHandlersEntry)

pub fn connect(
  config: Configuration,
  conn_handler: fn(HomeAssistant) -> HomeAssistant,
) -> Result(Nil, GlomeError) {
  let ha_api_path = case config.host {
    "supervisor" -> "/core/websocket"
    _ -> "/api/websocket"
  }
  let subject = process.new_subject()
  let selector =
    process.new_selector()
    |> process.selecting(subject, fn(x) { x })

  process.start(linked: True, running: fn() {
    let assert Ok(connection) =
      websocket.connect(config.host, ha_api_path, config.port, [])
      |> error.map_connection_error

    let assert Ok(_) =
      authentication.authenticate(connection, config.access_token)
    let assert Ok(_) = start_state_loop(connection, subject)
  })

  let home_assistant = HomeAssistant(handlers: list.new(), config: config)

  let handlers: StateChangeHandlers = conn_handler(home_assistant).handlers

  loops.start_state_change_event_receiver(fn() {
    let state_changed_event: StateChangeEvent = process.select_forever(selector)

    list.filter(handlers, fn(entry: StateChangeHandlersEntry) {
      entry.entity_selector.domain == state_changed_event.entity_id.domain
      && case entry.entity_selector.object_id {
        ObjectId(object_id) ->
          object_id == state_changed_event.entity_id.object_id
        All -> True
        Regex(pattern) ->
          regex.from_string(pattern)
          |> result.map(regex.check(_, state_changed_event.entity_id.object_id))
          |> result.unwrap(or: False)
      }
    })
    |> list.filter(fn(entry: StateChangeHandlersEntry) {
      entry.filter(state_changed_event, home_assistant)
    })
    |> list.map(fn(entry: StateChangeHandlersEntry) {
      process.start(linked: True, running: fn() {
        let result = entry.handler(state_changed_event, home_assistant)
        case result {
          Ok(Nil) -> Nil
          Error(error) -> {
            io.debug(error)
            Nil
          }
        }
      })
    })
    Ok(Nil)
  })
  Ok(Nil)
}

pub fn add_handler(
  to home_assistant: HomeAssistant,
  for entity_selector: EntitySelector,
  handler handler: StateChangeHandler,
) -> HomeAssistant {
  let handlers =
    do_add_handler_with_filter(
      home_assistant.handlers,
      entity_selector,
      handler,
      fn(_, _) { True },
    )
  HomeAssistant(..home_assistant, handlers: handlers)
}

pub fn add_constrained_handler(
  to home_assistant: HomeAssistant,
  for entity_selector: EntitySelector,
  handler handler: StateChangeHandler,
  constraint filter: StateChangeFilter,
) -> HomeAssistant {
  let handlers =
    do_add_handler_with_filter(
      home_assistant.handlers,
      entity_selector,
      handler,
      filter,
    )
  HomeAssistant(..home_assistant, handlers: handlers)
}

pub fn call_service(
  home_assistant: HomeAssistant,
  domain: Domain,
  service: Service,
  targets: Option(List(Target)),
  data: Option(String),
) -> Result(String, GlomeError) {
  let extract_target_value = fn(target: Target) {
    case target {
      Entity(value) -> entity_id.to_string(value)
      Area(value) -> value
      Device(value) -> value
    }
  }
  let convert_target = fn(item: #(String, List(Target))) {
    #(item.0, array(list.map(item.1, extract_target_value), string))
  }

  let targets_json =
    option.then(targets, fn(value: List(Target)) {
      util.group(value, with: fn(item) {
        case item {
          Entity(_) -> "entity_id"
          Area(_) -> "area_id"
          Device(_) -> "device_id"
        }
      })
      |> list.map(convert_target)
      |> json.object
      |> Some
    })

  let service_data =
    option.then(targets_json, fn(value) {
      value
      |> json.to_string
      |> Some
    })

  service.call(home_assistant.config, domain, service, service_data)
}

pub fn get_state(
  from home_assistant: HomeAssistant,
  of entity_id: EntityId,
) -> Result(State, GlomeError) {
  state.get(home_assistant.config, entity_id)
}

// PRIVATE API
fn do_add_handler_with_filter(
  in handlers: StateChangeHandlers,
  for entity_selector: EntitySelector,
  handler handler: StateChangeHandler,
  predicate filter: StateChangeFilter,
) -> StateChangeHandlers {
  list.append(handlers, [
    StateChangeHandlersEntry(entity_selector, handler, filter),
  ])
}

fn start_state_loop(
  connection: Connection,
  subject: Subject(StateChangeEvent),
) -> Result(Nil, GlomeError) {
  let subscribe_state_change_events =
    json.to_string(
      object([
        #("id", string("1")),
        #("type", string("subscribe_events")),
        #("event_type", string("state_changed")),
      ]),
    )

  websocket.send(connection, subscribe_state_change_events)
  case websocket.receive(connection, 500) {
    Ok(Text(message)) -> Ok(io.debug(message))
    Error(_) | _ -> Error(LoopNil)
  }
  loops.start_state_change_event_publisher(fn() {
    case websocket.receive(connection, 500) {
      Ok(Text(message)) -> publish_state_change_event(subject, message)
      Error(_) | _ -> Error(LoopNil)
    }
  })
  Ok(Nil)
}

fn publish_state_change_event(
  subject: Subject(StateChangeEvent),
  message: String,
) -> Result(Nil, GlomeError) {
  use state_change_event <- result.try(state_change_event.decode(message))
  process.send(subject, state_change_event)
  Ok(Nil)
}
