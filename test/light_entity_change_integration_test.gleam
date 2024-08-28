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
  let mock_event = dynamic.from([
    #("entity_id", dynamic.from("light.test_light")),
    #("state", dynamic.from("on")),
    #("brightness", dynamic.from(200)),
    #("rgb_color", dynamic.from([100, 150, 200])),
  ])

  // Trigger the state change handler with the mock event
  let assert Ok(Nil) = state_change_handler(mock_event, ha)

  // For testing purposes, we'll decode the mock event directly
  let assert Ok(light_change) = decode_light_entity_change(mock_event)

  // Assert the test results
  light_change.entity_id |> should.equal("light.test_light")
  light_change.state |> should.equal("on")
  light_change.brightness |> should.equal(Some(200))
  light_change.rgb_color |> should.equal(Some(#(100, 150, 200)))

  // Test with invalid data
  let invalid_event = dynamic.from([
    #("entity_id", dynamic.from("light.test_light")),
    #("state", dynamic.from("invalid")),
    #("brightness", dynamic.from("not_a_number")),
  ])

  let assert Error(Nil) = state_change_handler(invalid_event, ha)
}
