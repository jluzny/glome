import gleam/result
import gleam/option.{type Option, None, Some}
import gleam/io
import gleam/string
import gleam/httpc
import gleam/http.{type Method, Get, Http, Post}
import gleam/http/request
import glome/core/authentication
import glome/core/error.{
  type GlomeError, BadRequest, CallServiceError, NotAllowedHttpMethod, NotFound,
}

pub fn send_ha_rest_api_request(
  host: String,
  port: Int,
  access_token: authentication.AccessToken,
  method: Method,
  path_elements: List(String),
  body: Option(String),
) -> Result(String, GlomeError) {
  use method <- result.try(ensure_post_or_get(method))
  let req =
    request.new()
    |> request.set_scheme(Http)
    |> request.set_host(host)
    |> request.set_port(port)
    |> request.prepend_header("accept", "application/json")
    |> request.prepend_header(
      "Authorization",
      string.append("Bearer ", access_token.value),
    )
    |> request.set_method(method)
    |> request.set_path(string.concat(["/api", ..path_elements]))

  let req = case body {
    Some(data) -> request.set_body(req, data)
    None -> req
  }

  io.debug(req)

  use resp <- result.try(
    httpc.send(req)
    |> result.map_error(fn(error) {
      io.debug(error)
      CallServiceError("Error calling service")
    }),
  )

  case resp.status {
    200 -> Ok(resp.body)
    400 -> Error(BadRequest(resp.body))
    404 -> Error(NotFound(resp.body))
    _ -> Error(CallServiceError("Error calling service"))
  }
}

fn ensure_post_or_get(method: Method) {
  case method {
    Post | Get -> Ok(method)
    _ -> Error(NotAllowedHttpMethod)
  }
}
