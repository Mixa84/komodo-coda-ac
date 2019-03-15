open Core
open Async
open Stationary
open Common

let disqus_html name =
  Printf.sprintf
    {html|<div id="disqus_thread"></div>
<script>

/**
*  RECOMMENDED CONFIGURATION VARIABLES: EDIT AND UNCOMMENT THE SECTION BELOW TO INSERT DYNAMIC VALUES FROM YOUR PLATFORM OR CMS.
*  LEARN WHY DEFINING THESE VARIABLES IS IMPORTANT: https://disqus.com/admin/universalcode/#configuration-variables*/
var disqus_config = function () {
this.page.url = "https://codaprotocol.com/blog/%s.html";  // Replace PAGE_URL with your page's canonical URL variable
this.page.identifier = "codaprotocol/blog/%s?1"; // Replace PAGE_IDENTIFIER with your page's unique identifier variable
};
(function() { // DON'T EDIT BELOW THIS LINE
var d = document, s = d.createElement('script');
s.src = 'https://codaprotocol-com.disqus.com/embed.js';
s.setAttribute('data-timestamp', +new Date());
(d.head || d.body).appendChild(s);
})();
</script>
                        <noscript>Please enable JavaScript to view the <a href="https://disqus.com/?ref_noscript">comments powered by Disqus.</a></noscript>|html}
    name name

let title ~standalone ~name s =
  let open Html_concise in
  let t =
    h1
      [Style.just "f2 f1-ns ddinexp tracked-tightish pt2 pt3-m pt4-l mb1"]
      [text s]
  in
  if standalone then t
  else a [Style.just "blueblack"; href (sprintf "/blog/%s.html" name)] [t]

let subtitle s =
  let open Html_concise in
  h2 [Style.just "f4 f3-ns ddinexp mt0 mb4 fw4"] [text s]

let author s website =
  let open Html_concise in
  h4
    [Style.just "f7 fw4 tracked-supermega ttu metropolis mt0 mb1"]
    ( match website with
    | Some url ->
        [ a
            [ Attribute.href url
            ; Style.just "blueblack no-underline"
            ; Attribute.create "target" "_blank" ]
            [ span [Style.just "mr2"] [text ("by " ^ s)]
            ; literal
                {literal|<i class="ml-1 ml-2-ns fab f7 fa-twitter mr3 mr2-m mr3-l"></i>|literal}
            ] ]
    | None -> [text ("by " ^ s)] )

let date d =
  let month_day = Date.format d "%B %d" in
  let year = Date.year d in
  let s = month_day ^ " " ^ Int.to_string year in
  let open Html_concise in
  h4
    [Style.just "f7 fw4 tracked-supermega ttu o-50 metropolis mt0 mb45"]
    [text s]

module Share = struct
  open Html_concise

  let content =
    let channels =
      [ ("Twitter", "https://twitter.com/codaprotocol")
      ; ("Discord", "https://discord.gg/UyqY37F")
      ; ("Telegram", "https://t.me/codaprotocol")
      ; ("Hacker News", "https://news.ycombinator.com/item?id=18726110") ]
    in
    let channels =
      List.map channels ~f:(fun (name, link) -> a [href link] [text name])
    in
    let channels = List.intersperse channels ~sep:(text "•") in
    let share =
      span
        [Style.just "f7 ttu fw4 ddinexp tracked-mega blueshare"]
        [text "share:"]
    in
    div
      [Style.just "share flex justify-center items-center mb4"]
      (share :: channels)
end

let markdown_path name = "posts/" ^ name ^ ".markdown"

let post ~standalone name (post : Post.t) =
  let open Html_concise in
  let content_chunk =
    title ~standalone ~name post.title
    :: (match post.subtitle with None -> [] | Some s -> [subtitle s])
    @ [ author post.author post.author_website
      ; date post.date
      ; div
          [Stationary.Attribute.class_ "blog-content lh-copy"]
          [ post.content
          ; hr []
          (* HACK: to reuse styles from blog hr, we can just stick it in blog-content *)
           ]
      ; Share.content ]
  in
  let regular =
    div [Style.just "mw65-ns ibmplex f5 center blueblack"] content_chunk
  in
  let big =
    div
      [Style.just "mw7 center ibmplex blueblack side-footnotes"]
      [div [Style.just "mw65-ns f5 left blueblack"] content_chunk]
  in
  let disqus =
    if standalone then
      [ div
          [Style.just "mw65-ns ibmplex f5 center blueblack"]
          [Html.literal (disqus_html name)] ]
    else []
  in
  div
    [Style.just "ph3 ph4-m ph5-l"]
    ([Huge_switch.create ~regular ~huge:big] @ disqus)

let wrap p =
  wrap
    ~headers:
      [ Html.literal
          {html|<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/katex.min.css" integrity="sha384-9eLZqc9ds8eNjO3TmqPeYcDj8n+Qfa4nuSiGYa6DjLNcv9BtN69ZIulL9+8CqC9Y" crossorigin="anonymous">|html}
      ; Html.literal
          {html|<script defer src="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/katex.min.js" integrity="sha384-K3vbOmF2BtaVai+Qk37uypf7VrgBubhQreNQe9aGsz9lB63dIFiQVlJbr92dw2Lx" crossorigin="anonymous"></script>|html}
      ; Html.literal
          {html|<link rel="stylesheet" href="/static/css/blog.css">|html}
      ; Html.literal
          {html|<script defer src="https://cdn.jsdelivr.net/npm/katex@0.10.0/dist/contrib/auto-render.min.js" integrity="sha384-kmZOZB5ObwgQnS/DuDg6TScgOiWWBiVt0plIRkZCmE6rDZGrEOQeHM5PcHi+nyqe" crossorigin="anonymous"
    onload="renderMathInElement(document.body);"></script>|html}
      ; Html.literal
          {html|<script>
            document.addEventListener("DOMContentLoaded", function() {
              var blocks = document.querySelectorAll(".katex-block code");
              for (var i = 0; i < blocks.length; i++) {
                var b = blocks[i];
                katex.render(b.innerText, b, {displayMode:true});
              }
            });
          </script>|html}
      ; Html.literal
          {html|<script>
            document.addEventListener("DOMContentLoaded", function() {
              var blocks = document.querySelectorAll(".blog-content a");
              for (var i = 0; i < blocks.length; i++) {
                var b = blocks[i];
                if (b.href.indexOf('#') === -1) {
                  b.target = '_blank';
                }
              }
            });
          </script>|html}
      ]
    ~tight:true ~fixed_footer:false
    ~page_label:Links.(label blog)
    p

let content (name, p) =
  let p = post ~standalone:true name p in
  wrap [(fun _ -> p)]

let index nps =
  let ps = List.map nps ~f:(fun (n, p) -> post ~standalone:false n p) in
  wrap (List.map ps ~f:(fun p _ -> p))

let files names =
  let%map posts =
    Deferred.List.map names ~f:(fun name ->
        let%map p = Post.load (markdown_path name) in
        (name, p) )
    >>| List.sort ~compare:(fun (_, p1) (_, p2) ->
            -Date.compare p1.Post.date p2.Post.date )
  in
  let open File_system in
  file (File.of_html_path ~name:"blog/index.html" (index posts))
  :: List.map posts ~f:(fun (n, p) ->
         file
           (File.of_html_path ~name:(sprintf "blog/%s.html" n) (content (n, p)))
     )
