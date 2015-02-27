# matdoc: javadoc for MATLAB

Simply add `matdoc` to your MATLAB path and then run using:

```matlab
% matdoc takes files, folders or package names.
matdoc({'example.m', 'org.mitre', 'src/matlab'}, 'outDir', 'docs');
```

You'll end up with a subdirectory called `docs` that has the documentation
in it.

Developed on R2011b.
