require_relative "lib/lockbox/version"

Gem::Specification.new do |spec|
  spec.name          = "lockbox"
  spec.version       = Lockbox::VERSION
  spec.summary       = "Modern encryption for Ruby and Rails"
  spec.homepage      = "https://github.com/ankane/lockbox"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@chartkick.com"

  spec.files         = Dir["*.{md,txt}", "{lib}/**/*"]
  spec.require_path  = "lib"

  spec.required_ruby_version = ">= 2.4"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "carrierwave"
  spec.add_development_dependency "combustion", ">= 1.3"
  spec.add_development_dependency "rails"
  spec.add_development_dependency "minitest", ">= 5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rbnacl", ">= 6"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "mysql2"
  spec.add_development_dependency "shrine"
  spec.add_development_dependency "shrine-mongoid"
  spec.add_development_dependency "benchmark-ips"
end
