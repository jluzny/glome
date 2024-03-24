import gleam/dynamic.{type Dynamic, field, optional}
import gleam/option.{type Option}
import gleam/result
import glome/core/error.{type GlomeError}
import glome/core/serde
import glome/homeassistant/entity_id.{type EntityId}
import glome/homeassistant/state.{type State}

pub type StateChangeEvent {
  StateChangeEvent(
    entity_id: EntityId,
    old_state: Option(State),
    new_state: Option(State),
  )
}

pub fn decode(json_string: String) -> Result(StateChangeEvent, GlomeError) {
  json_string
  |> serde.decode_to_dynamic
  |> result.then(serde.get_field_by_path(_, "event.data"))
  |> result.then(decoder)
}

fn decoder(data: Dynamic) -> Result(StateChangeEvent, GlomeError) {
  let entity_id_decoder = field("entity_id", entity_id.decoder)

  use entity_id <- result.try(
    entity_id_decoder(data)
    |> error.map_decode_errors,
  )

  data
  |> dynamic.decode3(
    StateChangeEvent,
    entity_id_decoder,
    field("new_state", optional(state.decode(_, entity_id.domain))),
    field("old_state", optional(state.decode(_, entity_id.domain))),
  )
  |> error.map_decode_errors
}
