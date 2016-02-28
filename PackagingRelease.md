## Post-build ##

We have a post-build script phase to cleanup resulting .app and making zh_{CN, TW} nibs._

## Packaging ##

First of all, update the changelog in Changelog.markdown, Changelog.zh\_CN,markdown and Changelog.zh\_TW.markdown for each language. They are in Markdown syntax.

Then use `package.py` to package the resulting .app, like this:

```
$ ./package.py build/Release/Nally.app http://nally.googlecode.com/files
[PACK] Building Nally-1.4.5.zip...
[PACK] Signing Nally-1.4.5.zip...
[PACK] Generating Nally.xml...
[PACK] Generating Nally.zh_CN.xml...
[PACK] Generating Nally.zh_TW.xml...
Done! Please publish Nally-1.4.5.zip to http://nally.googlecode.com/files/Nally-1.4.5.zip.
```

## Release ##

After that, first upload the zip file to google code Downloads section. Then you can do svn commit to update the appcast files (Nally.xml, Nally.zh\_CN.xml, Nally.zh\_TW.xml).