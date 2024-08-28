import gleam/dynamic.{type DecodeError, type Dynamic}
import gleam/erlang/process
import gleam/io
import gleam/json
import gleam/option.{type Option, Some}
import gleeunit/should
import glome/core/authentication.{AccessToken}
import glome/core/error.{type GlomeError}
import glome/homeassistant.{
  type HomeAssistant, type StateChangeEvent, type StateChangeHandler,
}
import glome/homeassistant/domain.{Light}
import glome/homeassistant/entity_selector.{All, EntitySelector}
import glome/homeassistant/environment.{Configuration}

pub type LightEntityChange {
  LightEntityChange(
    entity_id: String,
    state: String,
    brightness: Option(Int),
    rgb_color: Option(#(Int, Int, Int)),
  )
}

fn decode_light_entity_change(
  data: Dynamic,
) -> Result(LightEntityChange, List(DecodeError)) {
  dynamic.decode4(
    LightEntityChange,
    dynamic.field("entity_id", dynamic.string),
    dynamic.field("state", dynamic.string),
    dynamic.field("brightness", dynamic.optional(dynamic.int)),
    dynamic.field(
      "rgb_color",
      dynamic.optional(dynamic.tuple3(dynamic.int, dynamic.int, dynamic.int)),
    ),
  )(data)
}

pub fn test_light_entity_change_integration() {
  // Create a mock configuration
  let config = Configuration("localhost", 8123, AccessToken("mock_token"))

  // Create a channel to receive test results
  let channel = process.new_channel()

  // Define the state change handler
  let state_change_handler: StateChangeHandler = fn(event, _ha) {
    case decode_light_entity_change(event.new_state) {
      Ok(light_change) -> {
        // Send the light change to the test channel
        process.send(channel.sender, light_change)
        Ok(Nil)
      }
      Error(err) -> {
        io.debug("Failed to decode light entity change")
        io.debug(err)
        Error(glome / core / error.DecodeError(err))
      }
    }
  }

  // Connect to Home Assistant (this will be mocked in the actual test environment)
  let assert Ok(ha) =
    homeassistant.connect(config, fn(ha) {
      // Add the state change handler for light entities
      let ha =
        homeassistant.add_handler(
          to: ha,
          for: EntitySelector(Light, All),
          handler: state_change_handler,
        )

      // Simulate a light entity change event
      let mock_event =
        StateChangeEvent(
          data: dynamic.from_json(
            json.object([
              #("entity_id", json.string("light.test_light")),
              #("state", json.string("on")),
              #("brightness", json.int(200)),
              #(
                "rgb_color",
                json.array([json.int(100), json.int(150), json.int(200)]),
              ),
            ]),
          ),
          new_state: dynamic.from_json(
            json.object([
              #("entity_id", json.string("light.test_light")),
              #("state", json.string("on")),
              #("brightness", json.int(200)),
              #(
                "rgb_color",
                json.array([json.int(100), json.int(150), json.int(200)]),
              ),
            ]),
          ),
          old_state: dynamic.from_json(
            json.object([
              #("entity_id", json.string("light.test_light")),
              #("state", json.string("off")),
            ]),
          ),
        )

      // Trigger the state change handler with the mock event
      let assert Ok(_) = state_change_handler(mock_event, ha)

      ha
    })

  // Receive the light change from the channel
  case process.receive(channel.receiver, 1000) {
    Ok(light_change) -> {
      light_change.entity_id
      |> should.equal("light.test_light")

      light_change.state
      |> should.equal("on")

      light_change.brightness
      |> should.equal(Some(200))

      light_change.rgb_color
      |> should.equal(Some(#(100, 150, 200)))
    }
    Error(_) -> should.fail()
  }
}
