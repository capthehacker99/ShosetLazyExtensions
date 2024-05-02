# Extensions - Universe

Community extensions for Shosetsu

## Source request

Simply create an issue with the tag `[SOURCE REQUEST]` and the source name next to it, then in the body paragraph have
the link to the source. It will be handled eventually

## Development

A very generic how to:

1. Fork this repository
2. Create a local clone of the repository on your pc
3. Choose what site you want to develop from, either from [issues][issues] or
   of your own choosing
4. Create a new branch on your local repository, following the following naming scheme `impl-thisisaname.domain`
5. Run `./dev-setup` to install documentation from the latest kotlin-lib
6. Start to develop the extension
   - You can use the following templates
     - [Lua Extension][lua-template]
7. Make a PR of that branch into master

### Icon creation

Unique Icons can be created for each extension. 
Following the above steps, but at step 5, develop the icon!

Please ensure the source of the icons are present, so they can be edited later on. 

[issues]: https://gitlab.com/shosetsuorg/extensions/-/issues/new
[lua-template]: https://gitlab.com/shosetsuorg/kotlin-lib/-/raw/main/templates/extension-template.lua
[js-template]:https://gitlab.com/shosetsuorg/kotlin-lib/-/raw/main/templates/extension-template.js