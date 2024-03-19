import gleam/result
import nerf/websocket.{type Connection}
import nerf/gun.{Text}
import glome/core/error.{type GlomeError, AuthenticationError}
import glome/core/serde
import gleam/json.{object, string}

pub type AccessToken {
  AccessToken(value: String)
}

pub fn authenticate(
  connection: Connection,
  access_token: AccessToken,
) -> Result(String, GlomeError) {
  let _ = authentication_phase_started(connection)
  let auth_message =
    object([
      #("type", string("auth")),
      #("access_token", string(access_token.value)),
    ])
    |> json.to_string
  websocket.send(connection, auth_message)

  use auth_response <- result.try(
    websocket.receive(connection, 500)
    |> result.map_error(fn(_) {
      AuthenticationError(
        "authentication failed! Auth result message not received!",
      )
    }),
  )
  let assert Text(auth_response) = auth_response

  use type_field <- result.try(
    serde.string_field(auth_response, "type")
    |> result.map_error(fn(_) {
      AuthenticationError(
        "authentication failed! Auth result message has no field [ type ]!",
      )
    }),
  )

  case type_field {
    "auth_ok" -> Ok("Authenticated connection established")
    "auth_invalid" -> Error(AuthenticationError("Invalid authentication"))
    _ ->
      Error(AuthenticationError("Something went wrong. Authentication failed!"))
  }
}

fn authentication_phase_started(
  connection: Connection,
) -> Result(String, GlomeError) {
  use initial_message <- result.try(
    websocket.receive(connection, 500)
    |> result.map_error(fn(_) {
      AuthenticationError(
        "could not start auth phase! Auth message not received!",
      )
    }),
  )
  let assert Text(initial_message) = initial_message

  use auth_required <- result.try(
    serde.string_field(initial_message, "type")
    |> result.map_error(fn(_) {
      AuthenticationError(
        "could not start auth phase! Auth message has no field [ type ]!",
      )
    }),
  )

  case auth_required {
    "auth_required" -> Ok(auth_required)
    _ ->
      Error(AuthenticationError(
        "Something went wrong. Authentication phase not started!",
      ))
  }
}
