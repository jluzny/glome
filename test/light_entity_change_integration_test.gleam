import gleam/dynamic.{type DecodeError, type Dynamic}
import gleam/io
import gleam/option.{type Option, Some, None}
import gleeunit/should
import glome/core/authentication.{AccessToken}
import glome/homeassistant
import glome/homeassistant/domain.{Light}
import glome/homeassistant/entity_selector.{All, EntitySelector}
import glome/homeassistant/environment.{Configuration}
import gleam/result

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
  let decode_attributes = fn(attributes) {
    dynamic.decode2(
      fn(brightness, rgb_color) { #(brightness, rgb_color) },
      dynamic.optional(dynamic.field("brightness", dynamic.int)),
      dynamic.optional(dynamic.field(
        "rgb_color",
        dynamic.tuple3(dynamic.int, dynamic.int, dynamic.int),
      )),
    )(attributes)
  }

  dynamic.decode3(
    fn(entity_id, state, attributes) {
      LightEntityChange(
        entity_id: entity_id,
        state: state,
        brightness: attributes.0,
        rgb_color: attributes.1,
      )
    },
    dynamic.field("entity_id", dynamic.string),
    dynamic.field("state", dynamic.string),
    dynamic.field("attributes", decode_attributes),
  )(data)
}

pub fn test_light_entity_change_integration() {
  // Create a mock configuration
  let config = Configuration("localhost", 8123, AccessToken("mock_token"))

  // Define the state change handler
  let state_change_handler = fn(event: Dynamic, ha) {
    decode_light_entity_change(event)
    |> result.map_error(fn(err) {
      io.debug("Failed to decode light entity change")
      io.debug(err)
      err
    })
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
    #("attributes", dynamic.from([
      #("brightness", dynamic.from(200)),
      #("rgb_color", dynamic.from([100, 150, 200])),
    ])),
  ])

  // Trigger the state change handler with the mock event
  let assert Ok(light_change) = state_change_handler(mock_event, ha)

  // Assert the test results
  light_change.entity_id |> should.equal("light.test_light")
  light_change.state |> should.equal("on")
  light_change.brightness |> should.equal(Some(200))
  light_change.rgb_color |> should.equal(Some(#(100, 150, 200)))

  // Test with partial data (missing brightness)
  let partial_event = dynamic.from([
    #("entity_id", dynamic.from("light.test_light")),
    #("state", dynamic.from("off")),
    #("attributes", dynamic.from([
      #("rgb_color", dynamic.from([50, 100, 150])),
    ])),
  ])

  let assert Ok(partial_light_change) = state_change_handler(partial_event, ha)
  partial_light_change.entity_id |> should.equal("light.test_light")
  partial_light_change.state |> should.equal("off")
  partial_light_change.brightness |> should.equal(None)
  partial_light_change.rgb_color |> should.equal(Some(#(50, 100, 150)))

  // Test with invalid data
  let invalid_event = dynamic.from([
    #("entity_id", dynamic.from("light.test_light")),
    #("state", dynamic.from("invalid")),
    #("attributes", dynamic.from([
      #("brightness", dynamic.from("not_a_number")),
    ])),
  ])

  let assert Error(_) = state_change_handler(invalid_event, ha)
}
