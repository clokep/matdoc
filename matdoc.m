function matdoc(varargin)
% Generates MATLAB API documentation for a set of MATLAB class definitions.
% Assumes that all functions are on the MATLAB path.
%
% The first input is a cellstr of topics to document. Each can be:
%   m-filename  The file will be added to the list to be documented.
%   directory   All files in that directory get added.
%   package     Everything inside that package is added.
%
% A set of parameters can be used to configure matdoc:
%   outDir      A string output directory, defaults to 'docs'.
%   title       A string title for the index page, defaults to 'MATLAB
%               API'.
%   clean       Whether to delete outDir before creating it.
%
% @author Garrett Wampole (gwampole@mitre.org)
% @author Patrick Cloke (pcloke@mitre.org)

%
% The overall classification of this file is UNCLASSIFIED.
%
%                             NOTICE
%
%        This software was produced for the U. S. Government
%   under Contract No. W15P7T-10-C-F600 - W15P7T-13-C-F600, and is
%      subject to the Rights in Noncommercial Computer Software
%      and Noncommercial Computer Software Documentation Clause
%                (DFARS) 252.227-7014 (JUN 1995)
%
%    (c) 2010-2013 The MITRE Corporation. All Rights Reserved.
%

    % Create a parser for the input.
    parser = inputParser();
    parser.KeepUnmatched = true;
    parser.addRequired('topics', @(t) iscellstr(t) || ischar(t));
    parser.addParamValue('outDir', 'docs', @ischar);
    parser.addParamValue('title', 'MATLAB API', @ischar);
    parser.addParamValue('clean', false, @islogical);
    parser.parse(varargin{:});
    % Parse and save the input.
    input = parser.Results;
    
    % Ensure the topics is a cellstr.
    if (ischar(input.topics))
        input.topics = {input.topics};
    end

    % The location of documentation on the MathWork's website.
    techdocRoot = sprintf('http://www.mathworks.com/help/releases/R%s/techdoc/ref/', version('-release'));
    
    % Remove the output directory if desired.
    if (input.clean && exist(input.outDir, 'dir'))
        rmdir(input.outDir, 's');
    end
    
    % The list of things to generate documentation for.
    topics = {};
    for kt = 1:numel(input.topics)
        arg = input.topics{kt};
        
        % Check if the arg is a package and include everything in the
        % package.
        package = meta.package.fromName(arg);
        if (~isempty(package))
            % ... do stuff ...
            topics = [topics, package2topics(package)]; %#ok<AGROW>

        % Check if the arg is a directory (and include everything inside of
        % it).
        elseif (exist(arg, 'dir'))
            files = what(arg);
            
            for lt = 1:numel(files.packages)
               topics = [topics, package2topics(meta.package.fromName(files.packages{lt}))]; %#ok<AGROW>
            end
            
            files = regexprep([files.m, files.classes], '\.m$', '');
            topics = [topics, files']; %#ok<AGROW>

        % Check if the arg is just a file and include it.
        % TODO Ensure it is an m-file?
        elseif (exist(arg, 'file'))
            topics = [topics, regexprep(arg, '\.m$', '')]; %#ok<AGROW>
        end
    end
    
    % Topics that have already had documentation generated.
    processedTopics = {};
    % Files to copy out of the MATLAB installation.
    resourceFiles = {};
    % Iterate over each target and generate the documentation.
    for kt = 1:numel(topics)
        topic = topics{kt};

        writeDocumentation(topic);
    end
    
    processedTopics = sort(processedTopics);
    writeIndex();

    function url = writeDocumentation(topic)
    % Generates HTML documentation for the given MATLAB topic and returns a
    % relative URL to that topic.
        
        url = topic2url(topic);
        
        topicLoc = which(topic);
        if (~isempty(strfind(topicLoc, matlabroot)) || ...
            ~isempty(strfind(topicLoc, 'built-in')))
            % This is a built-in MATLAB function.
            url = [techdocRoot, url];
            return;
        end

        if (ismember(topic, processedTopics))
            % This page has already been generated, nothing to do!
            return;
        end

        % Do not attempt to generate unavailable help information.
        if (isempty(help(topic)))
            url = '';
            return;
        end
        fprintf('Processing %s\n', topic);
        html = help2html(topic);

        % Output files should be in folders.
        outFile = fullfile(input.outDir, topic2file(topic));
        topicOutDir = fileparts(outFile);
        if (~exist(topicOutDir, 'dir'))
            mkdir(topicOutDir);
        end

        fout = fopen(outFile, 'w');
        fprintf(fout, '%s', html);
        fclose(fout);

        processedTopics = [processedTopics, {topic}];
        writeTopicMembers(outFile, topic);
    end

    function writeTopicMembers(topicDoc, topic)
    % Creates documentation for the members of the given MATLAB topic
    % documentation file.
    %
    % @param topicDoc The MATLAB HTML documentation file.
        % Pattern to match the contents of an href only.
        elemPattern = '(?:<a href="(.*?)">.*?</a>|<link rel="stylesheet" href="(.*?)">)';
        % Splits an element into the part before the href, the href, the
        % closing of the start tag, the text in the tag and the closing
        % tag.
        hrefPattern = '^(?<start><.+ href=")(?<href>[^"]*)(?<closeStart>">)(?<text>[^<]*)(?<end></a>)?$';
        helpwinPattern = 'matlab:helpwin\(''(.*)''\)';
        helpwinPattern2 = 'matlab:helpwin (.*)';

        d = fileread(topicDoc);

        [matches, splits] = regexp(d, elemPattern, 'match', 'split');

        fout = fopen(topicDoc, 'w');
        fprintf(fout, '%s', splits{1});

        for it = 1:numel(matches)
            hrefTokens = regexp(matches{it}, hrefPattern, 'tokens');
            if (~isempty(hrefTokens))
                hrefTokens = hrefTokens{1};
                href = hrefTokens{2};

                helpwinMatcher = regexp(href, helpwinPattern, 'tokens');
                helpwinMatcher2 = regexp(href, helpwinPattern2, 'tokens');

                memberName = [];
                if (~isempty(helpwinMatcher))
                    memberName = helpwinMatcher{1}{1};
                elseif (~isempty(helpwinMatcher2))
                    memberName = helpwinMatcher2{1}{1};
                elseif (strstart(href, 'matlab:'))
                    % Remove the element here.
                    url = '';
                elseif (strstart(href, 'file:'))
                    % Copy the file and replace it with a relative path.
                    [~, filename, ext] = fileparts(href);
                    filename = [filename, ext]; %#ok<AGROW>
                    if (~ismember(href, resourceFiles))
                        copyfile(href(9:end), fullfile(input.outDir, filename));
                        resourceFiles = [resourceFiles, {href}]; %#ok<AGROW>
                    end
                    url = createRelativeUrl(filename, nnz('.' == topic));
                elseif (strstart(href, 'https?:') || strstart(href, '(sftp|ftps?):'))
                    % These external URLs are "OK" and should be left.
                    url = href;
                else
                    error('matdoc:UnexpectedHref', 'Unexpected href: %s', href);
                end

                if (~isempty(memberName))
                    url = writeDocumentation(memberName);
                    if (~isempty(url))
                        url = createRelativeUrl(url, nnz('.' == topic));
                    end
                end
            end
            
            if (~isempty(url))
                % If a URL is given, reprint the element with the new URL.
                fprintf(fout, '%s%s%s%s%s', hrefTokens{1}, url, hrefTokens{3:5});
            else
                % Otherwise, just print the text inside of the element.
                fprintf(fout, '%s', hrefTokens{4});
            end

            % Always print the trailing information.
            fprintf(fout, '%s', splits{it + 1});
        end

        fclose(fout);
    end
    
    function writeIndex()
    % Writes an index file with links to the given set of MATLAB class
    % documentation in the given directory.
        fprintf('Building index...');

        index = [ ...
            '<html>', ...
            sprintf('<head><title>%s</title>', input.title), ...
            '<link rel="stylesheet" href="helpwin.css"/>', ...
            '</head><body>', ...
            sprintf('<div class="title">%s</div>', input.title)];
        
        for it = 1:numel(processedTopics)
            name = processedTopics{it};
            
            % If there is no file available for the topic, assume it is a
            % sub-topic and don't include it on the index.
            if (isempty(which(name)))
                continue;
            end

            index = [index, sprintf( ...
                '<div class="name"><a href="%s">%s</a></div><br/>', ...
                topic2url(name), name)]; %#ok<AGROW>
        end
        index = [index, '</body></html>'];

        fout = fopen(fullfile(input.outDir, 'index.html'), 'w');
        fprintf(fout, '%s', index);
        fclose(fout);
        
        disp('done!')
    end
end

function topics = package2topics(package)
% Take a package and add everything inside of it (including sub-packages).

    % If the package doesn't exist, just return.
    if (isempty(package))
        return;
    end

    % The output variable.
    topics = {};

    % Iterate over the sub-packages and recursively get contents.
    for it = 1:numel(package.PackageList)
        subtopics = package2topics(package.PackageList(it));
        topics = [topics, subtopics]; %#ok<AGROW>
    end

    % Add any classes inside the package.
    topics = [topics, {package.ClassList.Name}];

    % Add any functions (m-files) inside the package.
    functions = {package.FunctionList.Name};
    for it = 1:numel(functions)
        functions{it} = [package.Name, '.', functions{it}];
    end

    topics = [topics, functions];
end

function url = createRelativeUrl(url, n)
    relUrl = [];
    for it = 1:n
        relUrl = [relUrl, '../']; %#ok<AGROW>
    end
    % Ensure we have a URL and not a filepath.
    url = strrep([relUrl, url], '\\', '/');
end

function url = topic2url(topic)
% Calculate the relative URL from the root directory.
    url = [strrep(topic, '.', '/'), '.html'];
end

function file = topic2file(topic)
    file = [strrep(topic, '.', filesep), '.html'];
end

function isstart = strstart(str, pattern)
% Check if a string starts with a pattern.
    loc = regexp(str, ['^', pattern], 'start');
    isstart = ~isempty(loc) && loc(1) == 1;
end
