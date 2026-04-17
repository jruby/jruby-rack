version_spec = ->(prefix, desc) { "~> #{desc.split(prefix).last.insert(1, ".")}.0" }

# rails#{MAJOR}#{MINOR} => config_obj
{
  "rails50" => {racks: %w[rack22], ext_gems: %w[mutex_m bigdecimal base64]},
  "rails52" => {racks: %w[rack22], ext_gems: %w[mutex_m bigdecimal]},
  "rails60" => {racks: %w[rack22], ext_gems: %w[mutex_m bigdecimal]},
  "rails61" => {racks: %w[rack22], ext_gems: %w[mutex_m bigdecimal]},
  "rails70" => {racks: %w[rack22]},
  "rails71" => {racks: %w[rack22]},
  "rails72" => {racks: %w[rack22]},
  "rails80" => {racks: %w[rack22]},
}.each do |rails_desc, c|
  c[:racks].each do |rack_desc|

    appraise "#{rails_desc}_#{rack_desc}" do
      group :default do
        gem "rack", version_spec.call("rack", rack_desc)
        gem "rails", version_spec.call("rails", rails_desc)

        c[:ext_gems]&.each do |gem_name|
          gem gem_name
        end
      end
    end
  end
end
