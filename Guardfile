# A sample Guardfile
# More info at https://github.com/guard/guard#readme

ENV['SKIP_RCOV'] = 'true'
guard 'rspec', :version => 2, :cli => '--format documentation' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec/" }
end
