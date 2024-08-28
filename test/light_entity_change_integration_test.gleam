import gleam/dynamic.{type DecodeError, type Dynamic}
import gleam/io
import gleam/json
import gleam/option.{type Option, Some}
import gleam/result
import gleeunit/should
import glome/core/authentication.{AccessToken}
import glome/homeassistant
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

  // Define the state change handler
  let state_change_handler = fn(event: Dynamic, ha) {
    case decode_light_entity_change(event) {
      Ok(light_change) -> {
        // In a real scenario, you might want to do something with light_change
        // For now, we'll just return Ok(Nil)
        Ok(Nil)
      }
      Error(err) -> {
        io.debug("Failed to decode light entity change")
        io.debug(err)
        Error(Nil)
      }
    }
  }

  // Connect to Home Assistant
  let assert Ok(ha) = homeassistant.connect(config, state_change_handler)

  // Add the state change handler for light entities
  let ha =
    homeassistant.add_handler(
      to: ha,
      for: EntitySelector(Light, All),
      handler: state_change_handler,
    )

  // Simulate a light entity change event
  let mock_event =
    json.object([
      #("entity_id", json.string("light.test_light")),
      #("state", json.string("on")),
      #("brightness", json.int(200)),
      #("rgb_color", json.array([json.int(100), json.int(150), json.int(200)])),
    ])
    |> json.to_string
    |> json.decode(dynamic.decoder)
    |> result.unwrap(dynamic.from(Nil))

  // Trigger the state change handler with the mock event
  let assert Ok(_) = state_change_handler(mock_event, ha)

  // For testing purposes, we'll decode the mock event directly
  let assert Ok(light_change) = decode_light_entity_change(mock_event)

  // Assert the test results
  let LightEntityChange(entity_id, state, brightness, rgb_color) = light_change
  entity_id
  |> should.equal("light.test_light")

  state
  |> should.equal("on")

  brightness
  |> should.equal(Some(200))

  rgb_color
  |> should.equal(Some(#(100, 150, 200)))
}
