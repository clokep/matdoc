function matdoc(varargin)
% Generates MATLAB API documentation for a set of MATLAB class definitions.
% Assumes that all functions are on the MATLAB path.
%
% @author Garrett Wampole (gwampole@mitre.org)
% @author Patrick Cloke (pcloke@mitre.org)

    outDir = fullfile('docs', 'matlab');
    
    matClasses = {};
    for it = 1:nargin
        arg = varargin{it};
        
        package = meta.package.fromName(arg);
        if (~isempty(package))
            % ... do stuff ...
            matClasses = [matClasses, package2topics(package)]; %#ok<AGROW>
        elseif (exist(arg, 'dir'))
            files = dir(fullfile(arg, '*.m'));
            files = regexprep({files.name}, '\.m$', '');
            matClasses = [matClasses, files]; %#ok<AGROW>
        end
    end
    
    processedFiles = {};
    
    for it = 1:numel(matClasses)
        matClass = matClasses{it};
        fprintf('Processing %s\n', matClass);

        outBaseName = matClass;
        if (ismember('/', outBaseName))
            outBaseName = regexprep(outBaseName, '/', '.');
        elseif (ismember('\\', outBaseName))
            outBaseName = regexprep(outBaseName, '\\', '.');
        end

        % Output files should be in folders.
        outFile = fullfile(outDir, topic2file(outBaseName));

        writeDocumentation(matClass, outFile);
        writeTopicMembers(outFile, matClass, outDir);

        processedFiles = [processedFiles, {outFile}]; %#ok<AGROW>
    end
    
    processedFiles = sort(processedFiles);
%     writeIndex(outFiles);
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

function writeDocumentation(topic, file)
% Generates HTML documentation for the given MATLAB topic.
    % XXX use this information to not have links for topics that don't
    % exist.
    % hasDocs = ~isempty(topic);
    html = help2html(topic);
    
    outDir = fileparts(file);
    if (~exist(outDir, 'dir'))
        mkdir(outDir);
    end
    
    fout = fopen(file, 'w');
    fprintf(fout, '%s', html);
    fclose(fout);
end

function writeTopicMembers(topicDoc, topic, outDir)
% Creates documentation for the members of the given MATLAB topic
% documentation file.
%
% @param topicDoc The MATLAB HTML documentation file.
    % Pattern to match the contents of an href only.
    hrefPattern = '(?<=<a href=")(.*?)(?=">)';
    helpwinPattern = 'matlab:helpwin\(''(.*)''\)';
    helpwinPattern2 = 'matlab:helpwin (.*)';

    d = fileread(topicDoc);
    
    [matches, splits] = regexp(d, hrefPattern, 'match', 'split');

    fout = fopen(topicDoc, 'w');
    fprintf(fout, '%s', splits{1});

    for it = 1:numel(matches)
        href = matches{it};
        if (~isempty(href))
            helpwinMatcher = regexp(href, helpwinPattern, 'tokens');
            helpwinMatcher2 = regexp(href, helpwinPattern2, 'tokens');

            memberName = [];

            if (~isempty(helpwinMatcher))
                memberName = helpwinMatcher{1}{1};
            elseif (~isempty(helpwinMatcher2))
                memberName = helpwinMatcher2{1}{1};
%             elseif (href.startsWith('matlab:'))
%                 elem.remove();
            end

            if (~isempty(memberName))
                outFile = fullfile(outDir, topic2file(memberName));

                writeDocumentation(memberName, outFile);
                href = fullfile(outDir, topic2url(memberName, topic));
            end
        end
        
        fprintf(fout, '%s%s', href, splits{it + 1});
    end

    fclose(fout);
end

function url = topic2url(topic, parentTopic)
    url = [ '../', ...
        regexprep(parentTopic, '.*?(\.|$)', '../'), ...
        regexprep(topic, '\.', '/'), '.html'];
end

function file = topic2file(topic)
    file = [regexprep(topic, '\.', filesep), '.html'];
end
