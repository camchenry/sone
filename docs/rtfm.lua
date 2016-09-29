--[=[--
@module rtfm   Read the fucking manual.

@env Configuration Environment

This script can be configured by command switches and a config file.

Configuration options can be specified with command line switches.
They should appear before the list of soure files being processed.

    lua rtfm.lua --template.title='My API Docs' myapi.lua

A *config file* is a file named `.rtfm.lua` in the current working directory.
Command line switches always override config file settings.

```lua
-- .rtfm.lua
template.title = 'My API Docs'
```

The configuration environment runs as an instance of `Generator`;
all members can be accessed as locals. This allows almost every
aspect of RTFM to be configured; even core functionality can be
monkey-patched from the config file.

@env Custom Template Environment

Custom templates generate documentation from a list of tags.

Set a custom template with the `template.text` or `template.path`
configuration options.

### Command line:

    lua rtfm.lua --template.path='mytemplate.html' src.lua > out.html

### Config file:

```lua
template.path='mytemplate.html'
-- or
template.text=[[ ... ]]
```

The custom template environment has access to these locals:

@field Template self   The `Template` object.

@field {number:TagDef} tags   List of tags to apply the template to.

@function write   Append text to output.
@param string text   Text to write.

@function define   Define a transformation rule.
@param string mode   Transformation mode.
@param string selector   Optional node selector.
@param function transform   Transformation callback function.

@function defer   Defer to another transformation rule.
@param string context   Context node.
@param string mode   Transformation mode.
@param string selector   Node selector.

@function descend   Descend into child nodes and defer.
@param string context   Context node.
@param string mode   Transformation mode.
@param string selector   Node selector.

@type TagDef

@field number level     Tag level. Lower levels are parents of higher levels.
@field number group     Group priority level. Lower groups come first.
@field string sort      The name of a field to sort by after grouping.
@field string pattern   Matching pattern. Captures are inserted into fields.
@field string fields    Comma-delimited list of fields to populate from pattern.
@field string alias     The name of another `TagDef` to inherit from.
@field string title     A name to display in the template for this tag.
@field boolean parametric   Whether to display a parameter list overview.

@end type
--]=]--
local rtfm = {}

local ALL = '(.*)'
local ONE_WORD = '([^%s]*)%s*(.*)'
local TWO_WORD = '([^%s]+)%s*([^%s]*)%s*(.*)'

local CREATE_DEFAULT_TAGDEFS = function ()
    return {
        ['file'] = { level = 1, group = 11, title = 'Files', merge = 'typename',
            pattern = ONE_WORD, fields = 'typename,info', sort = 'typename',
            nest = rtfm.nestMergedTag },
        ['module'] = { alias = 'file',
            title = 'Modules', group = 12 },
        ['script'] = { alias = 'file',
            title = 'Scripts', group = 13 },
        ['type'] = { level = 2, group = 29, title = 'Types',
            pattern = ONE_WORD, fields = 'typename,info', sort = 'typename',
            nest = rtfm.nestDocTag },
        ['env'] = { alias = 'type',
            pattern = ALL, title = 'Contexts', group = 21 },
        ['class'] = { alias = 'type',
            title = 'Classes', group = 22 },
        ['object'] = { alias = 'type',
            title = 'Objects', group = 23 },
        ['table'] = { alias = 'type',
            title = 'Tables', group = 24 },
        ['interface'] = { alias = 'type',
            title = 'Interfaces', group = 25 },
        ['field'] = { level = 3, group = 31, title = 'Fields',
            pattern = TWO_WORD, fields = 'type,name,info', sort = 'name',
            nest = rtfm.nestDocTag },
        ['function'] = { level = 3, group = 33, title = 'Functions',
            pattern = ONE_WORD, fields = 'typename,info', sort = 'typename',
            parametric = true, nest = rtfm.nestDocTag },
        ['constructor'] = { alias = 'function',
            title = 'Constructors', group = 32 },
        ['method'] = { alias = 'function',
            title = 'Methods', group = 34 },
        ['callback'] = { alias = 'function',
            title = 'Callbacks', group = 35 },
        ['continue'] = { alias = 'function',
            title = 'Continuations', group = 36 },
        ['param'] = { level = 4, title = 'Arguments',
            pattern = TWO_WORD, fields = 'type,name,info',
            nest = rtfm.nestDocTag },
        ['return'] = { level = 4, title = 'Returns',
            pattern = ONE_WORD, fields = 'type,info',
            nest = rtfm.nestDocTag },
        ['unknown'] = { level = 4, pattern = TWO_WORD,
            fields = 'type,name,info', nest = rtfm.nestDocTag },
        ['end'] = { pattern = ALL, fields = 'what',
            nest = rtfm.nestEndTag },
    }
end

local DEFAULT_TEMPLATE = [[<!doctype html>
<html><head><meta charset="utf-8">
<title><@= self.title @></title>
<@ local cdn = 'https://cdnjs.cloudflare.com/ajax/libs' @>
<link rel="stylesheet"
    href="<@= cdn @>/highlight.js/9.7.0/styles/default.min.css">
<style>
html, body { background-color:#666; color:#333; font-size:12px;
    margin:0; padding:0; font-family:Lucida Grande, Lucida Sans Unicode,
    Lucida Sans, Geneva, Verdana, Bitstream Vera Sans, sans-serif; }
code { font-family:Lucida Console, Lucida Sans Typewriter, monaco,
    Bitstream Vera Sans Mono, monospace; }
body > div, body > section > article { max-width:600px; padding:40px;
    margin:auto; background:#f8f8f8; box-shadow:0px 0px 26px #000; }
body > section > article + article, body > div + section > article {
    margin:100px auto; }
h1, h2, h3, h4, h5, h6, p { font-weight:normal; font-size:12px;
    margin:0; padding:0; }
h1 { color:#666; font-size:150%; margin:0; padding:0; border:none; }
section > h2 { display:none; }
section > h3 { display:none; }
section > h4 { color:#aaa; font-style:italic; font-size:130%; margin:8px 0; }
section > h5 { font-weight:bold; color:#999; margin:8px 0}
a { color:#39c; text-decoration:none; }
p { line-height:150%; margin: 1em 0; }
:target { text-decoration:underline; }
article > h2 { font-size:200%; }
article > h3 { font-size:140%; background:#ddd;
    margin:16px -48px;  padding:8px 48px;
    box-shadow:0 2px 4px rgba(0,0,0,0.2);  position:relative;
    border:1px solid white; text-shadow:0px 1px 1px #fff; }
article > h3:before { content:""; position:absolute; width:0px; height:0px; 
    bottom:-9px; left:-1px; border:4px solid #999; 
    border-bottom-color:transparent; border-left-color:transparent; }
article > h3:after { content:""; position:absolute; width:0px; height:0px;
    bottom:-9px; right:-1px; border:4px solid #999;
    border-bottom-color:transparent; border-right-color:transparent;  }
article > h3 > b { font-weight: normal; }
article > h4 { border:2px solid #eee; background:#eee;
    margin:0 -8px; padding:4px 8px; }
article > h4 + div { border:2px solid #eee;
    margin:0 -8px; padding:4px 8px; }
article > h4 .type { float:right; }
article > h5 { margin:8px 0 0; }
footer { text-align:center; margin:80px; color:#eee; font-style:italic; }
footer a { color:#fff; font-weight:bold; text-decoration:underline; }
.type { color: #666; }
.unknown { color: #c39; }
.primitive { color: #999; }
</style></head><body>
<@
    local idMap = {}
    local typenames = {}

    for _, tag in ipairs(tags.flat) do
        if tag.typename then typenames[tag.typename] = tag end
    end

    local primitives = { ['nil'] = true, ['number'] = true,
        ['string'] = true, ['boolean'] = true, ['table'] = true,
        ['function'] = true, ['thread'] = true, ['userdata'] = true }
@>

<@ define('list', 'name', function (tag) @>
    <@= tag.name @>
<@ end) @>

<@ define('list', 'name and prev and prev.id == id', function (tag) @>
    , <@= ' ' .. tag.name @>
<@ end) @>

<@ define('overview', 'typename', function (tag) @>
    <li>
        <a href="#<@= tag.typename @>"><@= tag.typename @></a>
        <p><@= tag.info:gsub('%..*', '.') @></p>
        <ul><@ descend(tag, 'overview') @></ul>
    </li>
<@ end) @>

<@ define('type', 'type', function (tag) @>
    <span class="type">
    <@ 
        for m1, m2, m3 in tag.type:gmatch('([^%a]*)([%a]+)(.?)') do
            if typenames[m2] then
                write(m1 .. '<a href="#' .. m2 .. '">'
                    .. m2 .. '</a>' .. m3)
            elseif primitives[m2] then
                write(m1 .. '<span class="primitive">'
                    .. m2 .. '</span>' .. m3)
            else
                write(m1 .. '<span class="unknown">'
                    .. m2 .. '</span>' .. m3)
            end
        end
    @>
    </span>
<@ end) @>

<@ define('typename', 'typename', function (tag) @>
    <@
        local id = ''
        if not idMap[tag.typename] and tag.level < 4 then
            id = ' id="' .. tag.typename .. '"'
            idMap[tag.typename] = tag
        end
        write('<b' .. id .. '>' .. tag.typename .. '</b> ')
    @>
<@ end) @>

<@ define('link', 'type', function (tag) @>
    <@ defer(tag, 'type') @>
<@ end) @>

<@ define('link', 'type and name', function (tag) @>
    <@ defer(tag, 'type') @>
    <b><@= ' ' .. tag.name @></b>
<@ end) @>

<@ define('link', 'typename', function (tag) @>
    <@ defer(tag, 'typename') @>
<@ end) @>

<@ define('link', 'typename and parametric', function (tag) @>
    <@ defer(tag, 'typename') @>
    (<@ descend(tag, 'list', 'id=="param"') @>)
<@ end) @>

<@ define('article', function (tag) @>
    <article>
        <@ if tag.type or tag.typename then @>
            <h<@= tag.level + 1 @>>
                <@ defer(tag, 'link') @>
            </h<@= tag.level + 1 @>>
        <@ end @>
        <div>
            <@ if tag.note then @><p><@= tag.note @></p><@ end @>
            <@ if tag.code then @>
                <pre><code><@= tag.info @></code></pre>
            <@ else @>
                <p><@= tag.info @></p>
            <@ end @>
            <@ descend(tag, 'main') @>
        </div>
    </article>
<@ end) @>

<@ define('main', 'not hidden', function (tag) @>
    <@ defer(tag, 'article') @>
<@ end) @>

<@ define('main', '(prev and prev.id) ~= id and not hidden', function (tag) @>
    <section>
        <h<@= tag.level + 1 @>>
            <@= tag.title or tag.id @>
        </h<@= tag.level + 1 @>>
        <@ defer(tag, 'article') @>
    </section>
<@ end) @>

<@ define('main', 'level == 1 and not hidden', function (tag) @>
    <section>
        <@ defer(tag, 'article') @>
    </section>
<@ end) @>

<@ if self.overview then @>
    <div>
        <h1><@= self.title @></h1>
        <nav><h3>Table of Contents</h3>
        <ul><@ descend(tags, 'overview') @></ul>
        </nav>
    </div>
<@ end @>

<@ descend(tags, 'main') @>

<footer>
    Documentation generated by
    <a href="about:blank">RTFM</a>.
</footer>
<script src="<@= cdn @>/markdown-it/8.0.0/markdown-it.min.js"></script>
<script src="<@= cdn @>/highlight.js/9.7.0/highlight.min.js"></script>
<script src="<@= cdn @>/highlight.js/9.7.0/languages/lua.min.js"></script>
<script>var md = markdownit({ html: true, linkify: true,
    highlight: function (str, lang) {
        if (lang && hljs.getLanguage(lang))
            try { return hljs.highlight(lang, str).value; } catch (_) {}
        return '' }});
var code_inline = md.renderer.rules.code_inline
md.renderer.rules.code_inline = function (a,b,c,d,e) {
    var o = code_inline.call(md.renderer.rules, a,b,c,d,e)
    if (document.getElementById(a[b].content))
        return '<a href="#' + a[b].content + '">' + o + '</a>'
    return o};
[].slice.apply(document.getElementsByTagName('p')).forEach(
function (e) { e.outerHTML = md.render(e.textContent) })</script>
</body>
</html>
]]

--- @function rtfm.launch   Launch the generator from the command line.
--- @param string ...    Arguments passed in from command line.
function rtfm.launch (...)
    -- Try to load config file
    local option = {}
    local env = setmetatable({}, { __index = function (self, index)
        return option.at[index] or _G[index]
    end })
    local configure = loadfile('.rtfm.lua', 't', env)
    if not configure then
        configure = function () end
    end
    if setfenv then
        setfenv(configure, env)
    end
    -- Parse command line args
    local source = 'local o, c = ... return function (t) o.at = t; c()\n'
    local argIndex = 1
    for i = 1, select('#', ...) do
        local option = select(i, ...)
        local s, e, k, v = option:find('^%-%-(.*)=(.*)')
        if not s then
            break
        end
        v = (v == 'true' or v == 'false' or v == 'nil') and v
            or tonumber(v) or ('%q'):format(v)
        source = source .. 't.' .. k .. '=' .. tostring(v) .. '\n'
        argIndex = i + 1
    end
    source = source .. 'end'
    -- Create and run a generator
    local generator = rtfm.Generator(loadstring(source)(option, configure))
    generator:run({ select(argIndex, ...) })
end


--- @function rtfm.nestDocTag   Default nesting function for regular tags.
function rtfm.nestDocTag (tag, levels, tags)
    -- put tag at top of level stack, fill holes, pop unrelated tags 
    levels[tag.level] = tag
    for i = 1, tag.level - 1 do
        levels[i] = levels[i] or false
    end
    while #levels > tag.level do
        levels[#levels] = nil
    end
    -- move the tag into the appropriate parent tag (next level down stack) 
    local parent
    local level = tag.level - 1
    while level > 0 and not parent do
        parent = levels[level]
        level = level - 1
    end
    if parent then
        tag.parent = parent
        parent[#parent + 1] = tag
        return true
    end
end

--- @function rtfm.nestEndTag   Default nesting function for end tags.
function rtfm.nestEndTag (tag, levels, tags)
    for i = #levels, 1, -1 do
        if levels[i] and levels[i].id == tag.what then
            for j = i, #levels do
                levels[j] = nil
            end
            return true
        end
    end
    io.stderr:write('\nMismatched "end" tag on line ' .. tag.line .. '\n')
    return true
end

--- @function rtfm.nestMergedTag   Default nesting function for merged tags.
function rtfm.nestMergedTag (tag, levels, tags)
    for _, other in ipairs(tags.flat) do
        if other[tag.merge] == tag[tag.merge]
        and other.id == tag.id then
            isMerged = other ~= tag
            tag = other
            break
        end
    end
    return rtfm.nestDocTag(tag, levels, tags) or isMerged
end

--[[--
@class Generator

Documentation generator.

Configuration files run with the Generator as their environment.
The first segment of any configuration option, such as `input` or
`template`, represents a Generator field.

The Generator is also responsible for organizing tags into a tree
structure after their extraction from input files.
--]]--

--- @method Generator:nestTags   Nest tags. 
local function nestTags (self, tags)
    local levels = {}
    local i = 0
    while i < #tags do
        i = i + 1
        if tags[i]:nest(levels, tags) then
            table.remove(tags, i)
            i = i - 1
        end
    end
end

--- @function Generator.sortFunc  Function passed to `table.sort`.
local function sortFunc (a, b)
    if a.level ~= b.level then
        return a.level > b.level
    end
    if a.group and b.group then
        if a.group ~= b.group then
            return a.group < b.group
        end
        if a.sort and a.sort == b.sort then
            for sort in a.sort:gmatch('(%a+)') do
                if a[sort] < b[sort] then
                    return true
                elseif a[sort] > b[sort] then
                    return false
                end
            end
        end
    end
    return a.index < b.index
end

--- @method Generator:sortTags   Sort nested tags and link them to siblings. 
local function sortTags (self, tags)
    table.sort(tags, self.sortFunc)
    for i, tag in ipairs(tags) do
        tag.prev = tags[i - 1]
        tag.next = tags[i + 1]
        self:sortTags(tag)
    end
end

--- @method Generator:run   Run the generator on a list of files.
--- @param {number:string} files   A table of source files to parse.
local function run (self, files)
    local tags = self.input:read(files)
    self:nestTags(tags)
    self:sortTags(tags)
    self.output:write(self.template:apply(tags))
end

--- @constructor rtfm.Generator   Creates a Generator instance.
--- @param ConfigCallback configure  An optional configuration callback.
function rtfm.Generator (configure)
    local generator = {}
    
    --- @field Template template   The template for generated output.
    generator.template = rtfm.Template(generator)
    
    --- @field Reader input   The source file reader.
    generator.input = rtfm.Reader(generator)
    
    --- @field Writer output   The documentation writer.
    generator.output = rtfm.Writer(generator)
    
    --- @field {string:TagDef} tag  Tag definitions, keyed by ID.
    generator.tag = CREATE_DEFAULT_TAGDEFS()
    
    generator.sortFunc = sortFunc
    generator.nestTags = nestTags
    generator.sortTags = sortTags
    generator.run = run
    
    if configure then
        configure(generator)
    end
    for _, tag in pairs(generator.tag) do
        if tag.alias then
            setmetatable(tag, { __index = generator.tag[tag.alias] })
        end
    end
    
    return generator
end

--- @class NodeSet  Internal template transformation helper.

--- @method NodeSet:test   Test a node to see if it meets a condition.
--- @param table node   The node to test.
--- @param string condition   The condition to check.
--- @return mixed  Returns a truthy value if the test passed.
local function test (self, node, condition)
    local env = setmetatable({}, { __index = node })
    local f = assert((loadstring or load)(
        'local self = ... return ' .. condition, nil, 't', env))
    return (setfenv and setfenv(f, env) or f)(node)
end

--- @method NodeSet:match   Test a node to see if it meets a condition.
--- @param string condition   The condition to check.
--- @param boolean descend   Whether to descend into child nodes.
--- @return NodeSet   Returns a new NodeSet containing matched nodes.
local function match (self, condition, descend)
    local ns = rtfm.NodeSet()
    condition = condition or 'true'
    for _, node in ipairs(self) do
        if descend then
            for _, child in ipairs(node) do
                if self:test(child, condition) then
                    ns[#ns + 1] = child
                end
            end
        elseif self:test(node, condition) then
            ns[#ns + 1] = node
        end
    end
    return ns
end

--- @constructor rtfm.NodeSet   Creates a NodeSet instance.
--- @param table ... A list of nodes in the set.
function rtfm.NodeSet (...)
    return { test = test, match = match, ... }
end

--- @class Template   Transforms tag data to desired output format.

--- @method Template:applyText   Apply the template.
--- @param string text   The full text of the template.
--- @param {number:TagDef} tags   List of tags to apply the template to.
local function applyText (self, text, tags)
    local open = '\nwrite[============[\n'
    local close = ']============]\n'
    if self.condense then
        local s, e, left, right = self.escapePattern:find('(.*)%(.*%)(.*)')
        text = text:gsub('[%s]*' .. left, left):gsub(right .. '[%s]*', right) 
    end
    local source = 'local self, tags, write, define, defer, descend = ... '
        .. open .. text
        :gsub(self.outputPattern, close .. 'write(%1\n)' .. open)
        :gsub(self.escapePattern, close .. '%1' .. open)
        .. close
    local func, reason = loadstring(source)
    if func then
        local buffer = {}
        func(
            self, 
            tags,
            function (text) buffer[#buffer + 1] = text end,
            function (...) return self:define(...) end,
            function (...) return self:delegate(false, ...) end,
            function (...) return self:delegate(true, ...) end)
        return table.concat(buffer)
    else
        return nil, reason
    end
end

--- @method Template:apply   Apply the template to a list of tags.
--- @param {number:TagDef} tags   List of tags to apply the template to.
--- @return string   Returns the generated output.
local function apply (self, tags)
    local text
    if self.path then
        local file = io.open(self.path)
        if file then
            text = file:read('*a')
        else
            io.stderr:write('\nTemplate file "' .. self.path
                .. '" not found.\nUsing built-in template.\n\n')
        end
        local result, reason = self:applyText(text, tags)
        if not result then
            io.stderr:write('\nError in template file.\n' .. reason .. '\n')
            text = nil
        end
    end
    if not text then
        return assert(self:applyText(self.text, tags))
    end
end

--- @method Template:define   Define a transformation rule.
--- @param string mode   Transformation mode.
--- @param string selector   Node selector.
--- @param function transform   Transformation callback function.
local function define (self, mode, selector, transform)
    self.rules[#self.rules + 1] = {
        mode = mode,
        selector = transform and selector or 'true',
        transform = transform or selector
    }
end

--- @method Template:delegate   Delegate to another transformation rule.
--- @param string context   Context node.
--- @param string mode   Transformation mode.
--- @param string selector   Node selector.
local function delegate (self, descend, node, mode, selector)
    local context = rtfm.NodeSet(node):match(selector, descend)
    local map = {}
    for _, rule in ipairs(self.rules) do
        if rule.mode == mode then
            local matches = context:match(rule.selector, false)
            for _, node in ipairs(matches) do
                map[node] = rule
            end
        end
    end
    for index, node in ipairs(context) do
        if map[node] then
            map[node].transform(node, index, context)
        end
    end
end

--- @constructor rtfm.Template   Creates a Template instance.
function rtfm.Template ()
    local template = {}
    --- @field string title   Main title to display in generated output.
    template.title = 'API Docs'
    --- @field string path   Path to a custom template.
    template.path = nil
    --- @field string text   Full text of the output template.
    template.text = DEFAULT_TEMPLATE
    --- @field boolean overview   Whether to display an API overview.
    template.overview = true
    --- @field string escapePattern   Pattern to escape Lua code.
    template.escapePattern = '<@(.-)@>'
    --- @field string outputPattern   Pattern to output results of expressions.
    template.outputPattern = '<@=(.-)@>'
    --- @field boolean condense   Eliminate whitespace around escape sequences.
    --- Whitespace may be explicitly written with `write` or `outputPattern`. 
    template.condense = true
    
    template.rules = {}
    template.apply = apply
    template.applyText = applyText
    template.define = define
    template.delegate = delegate
    
    return template
end

--- @class Reader   Parses the source files.

--- @method Reader:parseLine  Parse a line from a source file.
--- @param string line   Line of text to parse.
--- @param number lineNumber   Line number.
local function parseLine (self, line, lineNumber)
    local tags = self.tags
    local lastTag = tags[#tags]
    local column, _, id, data = line:find(self.sigil .. '([^%s]+)%s*(.*)')
    -- is this line a new tag?
    if id then
        if lastTag then
            lastTag.info = lastTag.info:gsub('\n*$', '')
        end
        local tag = setmetatable({}, {
            __index = self.generator.tag[id] or self.generator.tag.unknown
        })
        local m = { data:find(tag.pattern) }
        local i = 2
        for field in tag.fields:gmatch('[^,]+') do
            i = i + 1
            tag[field] = m[i]
        end
        tags[#tags + 1] = tag
        tags.flat[#tags.flat + 1] = tag
        tag.index = #tags
        tag.line = lineNumber
        tag.column = column
        tag.data = data
        tag.id = id
        tag.info = tag.info or ''
        return tag
    -- it's more info for the previous tag
    elseif lastTag then
        local left = line:sub(1, lastTag.column - 1)
        local right = line:sub(lastTag.column, -1)
        line = left:gsub('^[%s-]*', '') .. right
        if lastTag.info == '' then
            lastTag.info = line
        else
            lastTag.info = lastTag.info .. '\n' .. line
        end
    end
end

--- @method Reader:parseFile   Read a file and create tags from it.
--- @param string name   Name of file to parse.  
local function parseFile (self, name)
    local file = io.open(name)
    local inBlock = false
    local n = 0
    for line in file:lines() do
        n = n + 1
        if line:find(self.blockEndPattern) then -- found end of block
            inBlock = false
        end
        if inBlock or line:find(self.linePattern) then -- in block or line
            self:parseLine(line, n)
        end
        if line:find(self.blockStartPattern) then -- found start of block
            inBlock = true
        end
    end
    file:close()
end

--- @method Reader:read   Read some files return a list of tags.
--- @param {number:string} files   List of files to parse.
--- @return {number:TagDef}   Returns a list of extracted tags.
local function read (self, files)
    for _, name in ipairs(files) do
        self:parseFile(name)
    end
    return self.tags
end

--- @constructor rtfm.Reader   Creates a Reader instance.
--- @param Generator generator   The generator instance.
function rtfm.Reader (generator)
    local reader = {}
    
    reader.generator = generator
    reader.tags = { flat = {} }
    
    --- @field string sigil   The prefix character for tags; "@" by default.
    reader.sigil = '@'
    --- @field string blockStartPattern   Matches the start of a docblock.
    reader.blockStartPattern = '%-%-%[=*%[%-%-+'
    --- @field string blockEndPattern   Matches the end of a docblock.
    reader.blockEndPattern = '%-%-+%]=*%]'
    --- @field string linePattern   Matches a line with a docblock.
    reader.linePattern = '%-%-%-'
    
    reader.parseFile = parseFile
    reader.parseLine = parseLine
    reader.read = read
    
    return reader
end

--- @class Writer   Outputs the generated text.

--- @method Writer:write   Write to a file or stdout.
--- @param string text   Text (or binary) to write.
local function write (self, text)
    if self.path then
        local file = io.open(self.path, 'wb')
        file:write(text)
    else
        io.write(text)
    end
end

--- @constructor rtfm.Writer   Creates a Writer instance.
function rtfm.Writer ()
    local writer = {}
    --- @field string path   Path to output file. Uses stdout if omitted.
    writer.path = nil
    
    writer.write = write
    
    return writer
end

-- If running from the command line, launch the generator.
if arg and arg[0] and arg[0]:find('rtfm.lua$') then
    rtfm.launch(...)
end

return rtfm
