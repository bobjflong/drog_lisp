task :test do |_|
  system "for file in test/*.rb; do ruby $file; done"
end

task :rebuild do |_|
  `gem uninstall drog_lisp`
  `gem build drog_lisp.gemspec`
  `gem install --local drog_lisp-0.0.2.gem`
  system "for file in test/*.rb; do ruby $file; done"
end
