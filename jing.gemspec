lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jing/version"

Gem::Specification.new do |spec|
  spec.name          = "jing"
  spec.version       = Jing::VERSION
  spec.authors       = ["pachacamac"]
  spec.email         = ["pachacamac@inboxalias.com"]

  spec.summary       = %q{A tiny static site generator packing a punch - 静态网页生成器 Jing tai wang ye sheng cheng qi}
  spec.description   = %q{Yes yet another static site generator. Has built in support for Erb - and Markdown templates, Typescript compiler, Sass compiler, JavaScript/Css minifier, partial- and layout support, variable support, easily extendable.}
  spec.homepage      = "https://github.com/pachacamac/jing"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.require_paths = ["lib"]

  spec.executables = ["jing"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 13.0"
end
