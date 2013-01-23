function matdoc(varargin)
% Generates MATLAB API documentation for a set of MATLAB class definitions.
% Assumes that all functions are on the MATLAB path.
%
% @author Garrett Wampole (gwampole@mitre.org)
% @author Patrick Cloke (pcloke@mitre.org)

    rootOutDir = fullfile('docs', 'matlab');
    title = 'MATLAB API';
    
    techdocRoot = sprintf('http://www.mathworks.com/help/releases/R%s/techdoc/ref/', version('-release'));
    
    topics = {};
    for kt = 1:nargin
        arg = varargin{kt};
        
        package = meta.package.fromName(arg);
        if (~isempty(package))
            % ... do stuff ...
            topics = [topics, package2topics(package)]; %#ok<AGROW>
        elseif (exist(arg, 'dir'))
            files = what(arg);
            
            for lt = 1:numel(files.packages)
               topics = [topics, package2topics(meta.package.fromName(files.packages{lt}))]; %#ok<AGROW>
            end
            
            files = regexprep([files.m, files.classes], '\.m$', '');
            topics = [topics, files]; %#ok<AGROW>
        end
    end
    
    processedTopics = {};
    resourceFiles = {};
    for kt = 1:numel(topics)
        topic = topics{kt};

        writeDocumentation(topic);
    end
    
    processedTopics = sort(processedTopics);
    writeIndex();

    function url = writeDocumentation(topic)
    % Generates HTML documentation for the given MATLAB topic and returns a relative URL to that topic.
        
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
        outFile = fullfile(rootOutDir, topic2file(topic));
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
                elseif (strfind(href, 'matlab:') == 1)
                    % Remove the element here.
                    url = '';
                elseif (strfind(href, 'file:') == 1)
                    [~, filename, ext] = fileparts(href);
                    filename = [filename, ext]; %#ok<AGROW>
                    if (~ismember(href, resourceFiles))
                        copyfile(href(9:end), fullfile(rootOutDir, filename));
                        resourceFiles = [resourceFiles, {href}]; %#ok<AGROW>
                    end
                    url = createRelativeUrl(filename, nnz('.' == topic));
                else
                    error('matdoc:UnexpectedHref', 'Unexpected href: %s', href);
                end

                if (~isempty(memberName))
                    url = writeDocumentation(memberName);
                    if (~isempty(url))
                        httpLoc = strfind(url, 'http:');
                        if (isempty(httpLoc) || httpLoc ~= 1)
                            url = createRelativeUrl(url, nnz('.' == topic));
                        end
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
        
        if (isempty(title))
            title = 'MATLAB API';
        end

        index = [ ...
            '<html>', ...
            sprintf('<head><title>%s</title>', title), ...
            '<link rel="stylesheet" href="helpwin.css"/>', ...
            '</head><body>', ...
            sprintf('<div class="title">%s</div>', title)];
        
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

        fout = fopen(fullfile(rootOutDir, 'index.html'), 'w');
        fprintf(fout, '%s', index);
        fclose(fout);
        
        disp('done!')
    end
end

function topics = package2topics(package)
    if (isempty(package))
        return;
    end
    
    topics = {};
    for it = 1:numel(package.PackageList)
        subtopics = package2topics(package.PackageList(it));
        topics = [topics, subtopics]; %#ok<AGROW>
    end
    topics = [topics, {package.ClassList.Name}];
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
