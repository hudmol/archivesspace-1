{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "parent" => "field_query",
    "properties" => {

      "field" => {"type" => "string", "dynamic_enum" => "staff_field_query_field", "ifmissing" => "error"},

    },
  },
}
