import gleam/option.{type Option}
import gleam/http.{Post}
import glome/homeassistant/domain.{type Domain}
import glome/homeassistant/entity_id.{type EntityId}
import glome/homeassistant/environment.{type Configuration}
import glome/core/error.{type GlomeError}
import glome/core/ha_client

pub type Service {
  Service(String)
}

pub type Target {
  Entity(EntityId)
  Area(String)
  Device(String)
}

pub type ServiceData {
  ServiceData(target: Target)
}

pub fn call(
  config: Configuration,
  domain: Domain,
  service: Service,
  service_data: Option(String),
) -> Result(String, GlomeError) {
  let Service(service_value) = service
  ha_client.send_ha_rest_api_request(
    config.host,
    config.port,
    config.access_token,
    Post,
    ["/services", "/", domain.to_string(domain), "/", service_value],
    service_data,
  )
}
