template.title="Sone API Reference"
template.escapePattern = '{@(.-)@}'
template.outputPattern = '{@=(.-)@}'
template.text=[[
<!doctype html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <title>{@= self.title @}</title>
        {@ local cdn = 'https://cdnjs.cloudflare.com/ajax/libs' @}
        <link rel="stylesheet" href="{@= cdn @}/highlight.js/9.7.0/styles/default.min.css">
        <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Source+Sans+Pro:400,700">
        <link href="https://fonts.googleapis.com/css?family=Source+Code+Pro" rel="stylesheet"> 
        <link rel="stylesheet" href="style.css">
    </head>
    <body>
        {@
        local idMap = {}
        local typenames = {}

        for _, tag in ipairs(tags.flat) do
            if tag.typename then typenames[tag.typename] = tag end
        end

        local primitives = { 
            ['nil'] = true, 
            ['number'] = true,
            ['string'] = true, 
            ['boolean'] = true, 
            ['table'] = true,
            ['function'] = true, 
            ['thread'] = true, 
            ['userdata'] = true,
        }

        @}

        {@ define('list', 'name', function (tag) @}
            {@= tag.name @}
        {@ end) @}

        {@ define('list', 'name and prev and prev.id == id', function (tag) @}
        , {@= ' ' .. tag.name @}
        {@ end) @}

        {@ define('overview', 'typename', function (tag) @}
        <li>
            <a href="#{@= tag.typename @}">{@= tag.typename @}</a>
            <ul>{@ descend(tag, 'overview') @}</ul>
        </li>
        {@ end) @}

        {@ define('type', 'type', function (tag) @}
        <span class="type">
            {@ 
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
            @}
        </span>
        {@ end) @}

        {@ define('typename', 'typename', function (tag) @}
        {@
            local id = ''
            if not idMap[tag.typename] and tag.level < 4 then
                id = ' id="' .. tag.typename .. '"'
                idMap[tag.typename] = tag
            end
            write('<strong ' .. id .. '>' .. tag.typename .. '</strong> ')
        @}
        {@ end) @}

        {@ define('link', 'type', function (tag) @}
        {@ defer(tag, 'type') @}
        {@ end) @}

        {@ define('link', 'type and name', function (tag) @}
        {@ defer(tag, 'type') @}
        <strong>{@= ' ' .. tag.name @}</strong>
        {@ end) @}

        {@ define('link', 'typename', function (tag) @}
        {@ defer(tag, 'typename') @}
        {@ end) @}

        {@ define('link', 'typename and parametric', function (tag) @}
        {@ defer(tag, 'typename') @}
        ({@ descend(tag, 'list', 'id=="param"') @})
        {@ end) @}

        {@ define('article', function (tag) @}
        <article>
            {@ if tag.type or tag.typename then @}
                {@ 
                local class = ''
                if tag.title then
                    class = " class='".. tag.title .."'"
                end
                @}
                <h{@= tag.level + 1 @} {@= class @}>
                    {@ defer(tag, 'link') @}
                </h{@= tag.level + 1 @}>
            {@ else @}
            {@ end @}
            <div>
                {@ if tag.note then @}<p>{@= tag.note @}</p>{@ end @}
                {@ if tag.code then @}
                    <pre>
                        <code>{@= tag.info @}</code>
                    </pre>
                {@ else @}
                    <p>{@= tag.info @}</p>
                {@ end @}
                {@ descend(tag, 'main') @}
            </div>
        </article>
        {@ end) @}

        {@ define('main', 'not hidden', function (tag) @}
            {@ defer(tag, 'article') @}
        {@ end) @}

        {@ define('main', '(prev and prev.id) ~= id and not hidden', function (tag) @}
        <section>
            <h{@= tag.level + 1 @}>
            {@= tag.title or tag.id @}
            </h{@= tag.level + 1 @}>
            {@ defer(tag, 'article') @}
        </section>
        {@ end) @}

        {@ define('main', 'level == 1 and not hidden', function (tag) @}
        <section>
            {@ defer(tag, 'article') @}
        </section>
        {@ end) @}

        {@ if self.overview then @}
        <div class="contents">
            <h1>{@= self.title @}</h1>
            <nav><h3>Table of Contents</h3>
                <ul>{@ descend(tags, 'overview') @}</ul>
            </nav>
        </div>
        {@ end @}

        {@ descend(tags, 'main') @}

        <footer>
            <small>
            Documentation generated by <a href="https://github.com/airstruck/rtfm">RTFM</a>.
            <span>{@= os.date("%c") @}</span>
            </small>
        </footer>
        <script src="{@= cdn @}/markdown-it/8.0.0/markdown-it.min.js"></script>
        <script src="{@= cdn @}/highlight.js/9.7.0/highlight.min.js"></script>
        <script src="{@= cdn @}/highlight.js/9.7.0/languages/lua.min.js"></script>
        <script>
            var md = markdownit({
                html: true,
                linkify: true,
                highlight: function(str, lang) {
                    if (lang && hljs.getLanguage(lang))
                        try {
                            return hljs.highlight(lang, str).value;
                        } catch (_) {}
                    return ''
                }
            });
            var code_inline = md.renderer.rules.code_inline
            md.renderer.rules.code_inline = function(a, b, c, d, e) {
                var o = code_inline.call(md.renderer.rules, a, b, c, d, e)
                if (document.getElementById(a[b].content))
                    return '<a href="#' + a[b].content + '">' + o + '</a>'
                return o
            };
            [].slice.apply(document.getElementsByTagName('p')).forEach(
                function(e) {
                    e.outerHTML = md.render(e.textContent)
                })
        </script>
</body>
</html>

]]
