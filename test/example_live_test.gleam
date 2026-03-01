import gleam/erlang/atom
import gleam/io

import gleeunit
import glome/core/authentication.{AccessToken}
import glome/core/error.{type GlomeError}
import glome/homeassistant.{type HomeAssistant, type StateChangeHandler}
import glome/homeassistant/domain.{Sensor}
import glome/homeassistant/entity_selector.{All, EntitySelector}
import glome/homeassistant/environment.{Configuration}

pub fn main() {
  gleeunit.main()
}

pub fn gla_test_() {
  let assert Ok(timeout) = atom.from_string("timeout")
  #(timeout, 3600.0, [fn() { test_state_change() }])
}

pub fn test_state_change() -> Result(Nil, GlomeError) {
  let config =
    Configuration(
      "192.168.0.204",
      8123,
      AccessToken(
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIwMmE2YWYwMGMzZGU0OTVkYjY4ZGYwNmIzNTExNzA1ZSIsImlhdCI6MTY4NzYyMjUxNywiZXhwIjoyMDAyOTgyNTE3fQ.oN7TLY7LuAeaZRAqy68UygAxVsCzK_4EjqWQKuKv7UI",
      ),
    )

  homeassistant.connect(config, handle_connection)
}

fn handle_connection(ha: HomeAssistant) {
  io.debug("example_live_test.handle_connection: Connecting to Home Assistant")
  let state_change_handler: StateChangeHandler = fn(state_change_event, ha) -> Result(
    Nil,
    GlomeError,
  ) {
    let _ = ha
    io.debug(
      "example_live_test.handle_connection: State change event handling start.",
    )
    io.debug(state_change_event)
    io.debug(
      "example_live_test.handle_connection: State change event handling end.",
    )
    Ok(Nil)
  }

  homeassistant.add_handler(
    to: ha,
    for: EntitySelector(Sensor, All),
    handler: state_change_handler,
  )
}
