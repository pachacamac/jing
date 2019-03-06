gem build jing.gemspec
gemfile=$(ls *.gem | tail -n 1)
echo pushing $gemfile
gem push $gemfile
