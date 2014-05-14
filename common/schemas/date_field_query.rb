{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "properties" => {

      "comparator" => {"type" => "string", "enum" => ["greater_than", "lesser_than", "equal"]},
      "field" => {"type" => "string", "dynamic_enum" => "date_field_query_field", "ifmissing" => "error"},
      "value" => {"type" => "date", "ifmissing" => "error"},

    },
  },
}
