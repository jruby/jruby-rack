major_minor = ->(prefix, desc) { desc.split(prefix).last.insert(1, ".") }
version_spec = ->(prefix, desc) { "~> #{major_minor.call(prefix, desc)}.0" }

# Rails version -> rack versions in format
# rails#{MAJOR}#{MINOR} => %w[ rack#{MAJOR}#{MINOR} ]
{
    "rails72" => {racks: %w[rack22 rack31]},
    "rails80" => {racks: %w[rack22 rack31 rack32]},
    "rails81" => {racks: %w[rack31 rack32]}
}.each do |rails_desc, c|
  c[:racks].each do |rack_desc|

    appraise "#{rails_desc}_#{rack_desc}" do
      group :default do
        gem "rack", version_spec.call("rack", rack_desc)
        gem "rails", version_spec.call("rails", rails_desc)

        c[:ext_gems]&.each do |gem_name|
          gem gem_name
        end

        gem "rdoc", "!= 8.0.0" if major_minor.call("rails", rails_desc) >= "7.0"
      end
    end
  end
end
