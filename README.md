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

File endings work like Russian dolls: They get converted from outer to inner. Rails folks should be somewhat familiar with that but here it's a bit stricter.

Folders starting with `_` have special meaning, they generally won't get copied into the destination folder `_dst`.

`_partials` holds partials (TODO: explanation)

`_layouts` holds layouts (TODO: explanation)

`.meta.yml` holds global meta variables available in templates when not overwritten

~~I'll try and add a basic example project soon.~~ Check out the examples folder. If you feel like giving this a try and have questions feel free to open an issue or reach out otherwise. Pull requests welcome too.

## Development

Extending is fairly easy.

`@converters` variable in the initialize method holds a bunch of converters. Just add one in the spirit of the others. You can also do this on the fly when initiating the Jing Class by passing the `converter_addons` option.

Class methods that end in a bang `!` automatically are registered as cli commands. If you wish to add a command just add a bang-method and you should be done.

Feel free to open issues for questions / ideas etc that you don't know how to work on or have no time working on as well as actual bugs and quirky etc. I'm sure there are some.

Please fork and make a pull request if you want to contribute.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pachacamac/jing.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
