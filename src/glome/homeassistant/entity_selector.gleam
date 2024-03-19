import glome/homeassistant/domain.{type Domain}

pub type EntitySelector {
  EntitySelector(domain: Domain, object_id: Selector)
}

pub type Selector {
  ObjectId(String)
  All
  Regex(String)
}
