version_spec = ->(prefix, desc) { "~> #{desc.split(prefix).last.insert(1, ".")}.0" }

# Rails version -> rack versions in format
# rails#{MAJOR}#{MINOR} => %w[ rack#{MAJOR}#{MINOR} ]
{
    "rails61" => %w[rack22],
    "rails70" => %w[rack22],
    "rails71" => %w[rack22],
    "rails72" => %w[rack22],
    "rails80" => %w[rack22]
}.each do |rails_desc, rack_descs|
  rack_descs.each do |rack_desc|

    appraise "#{rails_desc}_#{rack_desc}" do
      group :default do
        gem "rack", version_spec.call("rack", rack_desc)
        gem "rails", version_spec.call("rails", rails_desc)
      end
    end
  end
end
