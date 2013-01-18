function matdoc(varargin)
% Generates MATLAB API documentation for a set of MATLAB class definitions.
% Assumes that all functions are on the MATLAB path.
%
% @author Garrett Wampole (gwampole@mitre.org)
% @author Patrick Cloke (pcloke@mitre.org)

    rootOutDir = fullfile('docs', 'matlab');
    
    topics = {};
    for kt = 1:nargin
        arg = varargin{kt};
        
        package = meta.package.fromName(arg);
        if (~isempty(package))
            % ... do stuff ...
            topics = [topics, package2topics(package)]; %#ok<AGROW>
        elseif (exist(arg, 'dir'))
            files = dir(fullfile(arg, '*.m'));
            files = regexprep({files.name}, '\.m$', '');
            topics = [topics, files]; %#ok<AGROW>
        end
    end
    
    processedTopics = {};
    for kt = 1:numel(topics)
        topic = topics{kt};

        writeDocumentation(topic);
    end
    
    processedTopics = sort(processedTopics);
%     writeIndex(outFiles);

    function writeDocumentation(topic)
    % Generates HTML documentation for the given MATLAB topic.

        if (ismember('/', topic))
            topic = regexprep(topic, '/', '.');
        elseif (ismember('\\', topic))
            topic = regexprep(topic, '\\', '.');
        end

        if (ismember(topic, processedTopics))
            % This page has already been generated, nothing to do!
            return;
        end

        topicLoc = which(topic);
        if (~isempty(strfind(topicLoc, matlabroot)) || ...
            ~isempty(strfind(topicLoc, 'built-in')))
            % This is a built-in MATLAB function.
            % XXX can we link this to online help docs?
            return;
        end

        fprintf('Processing %s\n', topic);

        % Output files should be in folders.
        outFile = fullfile(rootOutDir, topic2file(topic));

        % XXX use this information to not have links for topics that don't
        % exist.
        % hasDocs = ~isempty(topic);
        html = help2html(topic);

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
        aPattern = '<a href="(.*?)">';
        hrefPattern = '(?<=<a href=")(.*?)(?=">)';
        helpwinPattern = 'matlab:helpwin\(''(.*)''\)';
        helpwinPattern2 = 'matlab:helpwin (.*)';

        d = fileread(topicDoc);

        [matches, splits] = regexp(d, aPattern, 'match', 'split');

        fout = fopen(topicDoc, 'w');
        fprintf(fout, '%s', splits{1});

        for it = 1:numel(matches)
            [href, hrefSplits] = regexp(matches{it}, hrefPattern, 'tokens', 'split');
            if (~isempty(href))
                href = href{1}{1};
            else
                href = '';
            end
            
            if (~isempty(href))
                helpwinMatcher = regexp(href, helpwinPattern, 'tokens');
                helpwinMatcher2 = regexp(href, helpwinPattern2, 'tokens');

                memberName = [];
                if (~isempty(helpwinMatcher))
                    memberName = helpwinMatcher{1}{1};
                elseif (~isempty(helpwinMatcher2))
                    memberName = helpwinMatcher2{1}{1};
                elseif (strfind(href, 'matlab:') == 1)
                    % REmove the element here.
                else
                    error('matdoc:UnexpectedHref', 'Unexpected href: %s', href);
                end

                if (~isempty(memberName))
                    writeDocumentation(memberName);
                    href = fullfile(rootOutDir, topic2url(memberName, topic));
                    fprintf(fout, '%s%s%s', hrefSplits{1}, href, hrefSplits{2});
                end
            end

            % Always print the trailing information.
            fprintf(fout, '%s', splits{it + 1});
        end

        fclose(fout);
    end
end

function topics = package2topics(package)
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

function url = topic2url(topic, parentTopic)
    url = [ '../', ...
        regexprep(parentTopic, '.*?(\.|$)', '../'), ...
        regexprep(topic, '\.', '/'), '.html'];
end

function file = topic2file(topic)
    file = [regexprep(topic, '\.', filesep), '.html'];
end
