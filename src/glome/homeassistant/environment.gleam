import gleam/int
import gleam/option.{type Option}
import gleam/result
import glome/core/authentication.{type AccessToken, AccessToken}

pub type Configuration {
  Configuration(host: String, port: Int, access_token: AccessToken)
}

pub fn get_host() -> Option(String) {
  get_env("HOST")
  |> option.from_result
}

pub fn get_port() -> Option(Int) {
  get_env("PORT")
  |> result.then(int.parse)
  |> option.from_result
}

pub fn get_access_token() -> Option(AccessToken) {
  get_env("ACCESS_TOKEN")
  |> option.from_result
  |> option.map(AccessToken)
}

pub fn get_ha_supervisor_token() -> Option(AccessToken) {
  get_env("SUPERVISOR_TOKEN")
  |> option.from_result
  |> option.map(AccessToken)
}

@external(erlang, "system", "get_var")
pub fn get_env(var: String) -> Result(String, Nil)
