# Jing

A tiny static site generator packing a punch

Jing tai wang ye sheng cheng qi
静态网页生成器

---

Has built in support for Erb - and Markdown templates, Typescript compiler, Sass compiler, JavaScript/Css minifier, partial- and layout support, variable support, easily extendable.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jing'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jing

## Usage

call `jing` on the command line or have a look at the code (it's tiny) :)


Creates a new folder `mypage` with a basic setup:

    $ jing create mypage
    $ cd mypage
    
Build the current project:
    
    $ jing build
    
Automatically build the page whenever a file in the project folder changes:

    $ jing watch
    
Serves the current project folder on `http://0.0.0.0:8000`:
    
    $ jing serve

Folders starting with `_` have special meaning, they generally won't get copied into the destination folder `_dst`.

`_partials` holds partials (TODO: explanation)

`_layouts` holds layouts (TODO: explanation)

`.meta.yml` holds global meta variables available in templates when not overwritten

I'll try and add a basic example project soon. If you feel like wanting to giving this a try in the meantime feel free to open an issue or reach out otherwise.


## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pachacamac/jing.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
