Gem::Specification.new do |s|
  s.name              = "drog_lisp"
  s.version           = "0.0.2"
  s.platform          = Gem::Platform::RUBY
  s.authors           = ["Bob Long"]
  s.email             = ["robertjflong@gmail.com"]
  s.homepage          = "https://github.com/bobjflong/drog_lisp"
  s.summary           = "Embedded functional language for Ruby"
  s.description       = "Resembles Lisp or Scheme but with unqiue semantics. Supports first-class functions, continuations, recursion etc."
  s.rubyforge_project = s.name
  s.license = 'MIT'
  s.required_rubygems_version = ">= 1.3.6"

  # If you have runtime dependencies, add them here
  # s.add_runtime_dependency "other", "~> 1.2"

  # If you have development dependencies, add them here
  # s.add_development_dependency "another", "= 0.9"

  # The list of files to be contained in the gem
  s.files = Dir["{lib}/**/*.rb", "{lib}/**/*.rake", "{lib}/**/*.yml", "LICENSE", "*.md"]
  
  # s.executables   = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  # s.extensions    = `git ls-files ext/extconf.rb`.split("\n")

  s.require_path = 'lib'

  s.add_runtime_dependency 'whittle'
  s.add_runtime_dependency 'sxp'
  s.add_runtime_dependency 'pry'


  # For C extensions
  # s.extensions = "ext/extconf.rb"
end
