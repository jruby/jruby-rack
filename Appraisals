version_spec = ->(prefix, desc) { "~> #{desc.split(prefix).last.insert(1, ".")}.0" }

# Rails version -> rack versions in format
# rails#{MAJOR}#{MINOR} => %w[ rack#{MAJOR}#{MINOR} ]
{
    "rails72" => {racks: %w[rack22]},
    "rails80" => {racks: %w[rack22]}
}.each do |rails_desc, c|
  c[:racks].each do |rack_desc|

    appraise "#{rails_desc}_#{rack_desc}" do
      group :default do
        gem "rack", version_spec.call("rack", rack_desc)
        gem "rails", version_spec.call("rails", rails_desc)

        c[:ext_gems]&.each do |gem_name|
          gem gem_name
        end

        gem "rdoc", "!= 8.0.0" # Transitive of irb, broken on JRuby 10.x
      end
    end
  end
end
