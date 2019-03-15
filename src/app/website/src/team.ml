open Core
open Async
open Stationary
open Common

module Member = struct
  type t = {name: string; affiliation: string option; bio: string}

  let to_html {name; affiliation; bio} =
    let open Html in
    let open Html_concise in
    let top =
      let icon =
        let last_name =
          String.split ~on:' ' (String.lowercase name) |> List.last_exn
        in
        Icon.person last_name
      and name =
        h3
          [Style.(render (Styles.heading_style + ["black f4 fw5"]))]
          [text name]
      and affiliation =
        match affiliation with
        | None -> span [] []
        | Some affiliation ->
            h4
              [Style.(render (Styles.heading_style + ["silver f5"]))]
              [text affiliation]
      in
      div
        [class_ "flex items-center"]
        [ div [class_ "w-25"] [icon]
        ; div [class_ "ph4 w-100"] [name; affiliation] ]
    in
    div
      [class_ "ph3 ph4-ns pv3 relative team-card-shadow bg-white"]
      [top; p [Style.(render Styles.copytext)] [text bio]]
end

type t = Member.t list

let core () =
  let open Member in
  let plain name affiliation bio =
    {name; bio; affiliation= Some affiliation}
  in
  let advisor name = plain name "advisor" in
  let evan =
    plain "Evan Shapiro" "CEO"
      "Evan Shapiro graduated from Carnegie Mellon with a BS in computer \
       science. He then obtained his research MS while working in the CMU \
       Personal Robotics Lab, where he did research for the HERB robotics \
       platform. He has also worked as a software engineer for Mozilla."
  and izaak =
    plain "Izaak Meckler" "CTO"
      "Izaak Meckler is a mathematician and computer scientist. Most \
       recently, he was a PhD student studying cryptography at UC Berkeley. \
       Prior to that, he worked as a software engineer at trading firm Jane \
       Street, and has contributed to numerous open source projects including \
       the Elm compiler."
  and brad =
    plain "Brad Cohn" "Strategy & Operations"
      "Brad Cohn has diverse work experience, including stints in an \
       electrophysiology lab, high frequency trading firm, a technology think \
       tank, and a hedge fund. He most recently came from Bridgewater \
       Associates where he was an engineer on the currency team and Ray \
       Dalio's research team before joining a group of engineers dedicated to \
       rearchitecting core investment systems. He holds a BS in math from \
       UChicago with a minor in computational neuroscience."
  and brandon =
    plain "Brandon Kase" "Protocol Engineer"
      "Brandon Kase loves functional programming. He was first introduced to \
       it while pursuing his BS in computer science at Carnegie Mellon. He \
       has worked as a software engineer for Highlight (acquired by \
       Pinterest), Pinterest, Facebook, and Mozilla. Brandon is excited about \
       the safety and clarity strong statically typed functional programming \
       techniques can bring to the software industry. He also enjoys \
       proselytizing, so you may find him speaking at a conference near you."
  and corey =
    plain "Corey Richardson" "Protocol Engineer"
      "Corey Richardson is a seasoned open source contributor, recently \
       working primarily on the Rust compiler and libraries. They studied \
       computer science at Clarkson University and have worked at Dyn, \
       Mozilla, Leap Motion, and NICTA. They are especially interested in \
       formal verification, the seL4 microkernel, and what high powered \
       functional programming can do for trustworthy software."
  and deepthi =
    plain "Deepthi Kumar" "Protocol Engineer"
      "Deepthi is a functional programming enthusiast and software engineer. \
       In her recently completed master's work, Deepthi designed GitQL, a \
       novel embedded DSL for querying textual changes in software \
       repositories. Her interests span programming languages and program \
       analysis. Deepthi holds an MS in computer science from Oregon State \
       University and a BE from Visvesvaraya Technological University."
  and nathan =
    plain "Nathan Holland" "Protocol Engineer"
      "Nathan is a passionate, self-taught programmer who loves programming \
       languages and paradigms and using high-level abstractions to create \
       high-performance systems. Some of his favorite projects have been \
       developing an array programming languages that targeted GPUs, an \
       Elixir DSL for service buses, a MySql binary log deserializer, and a \
       VR-based window manager on Linux. Most recently, Nathan was building a \
       unique educational program to teach people how to program from the \
       ground up using simplified programming languages and a simple virtual \
       machine."
  and john =
    plain "John Wu" "Protocol Engineer"
      "John Wu obtained a BS in Applied Mathematics at UCLA and a MS in \
       Computer Science at NYU. His academic interests in CS and Math span \
       many different fields with particular focus on programming languages \
       and machine learning. His industry experience includes projects with \
       Visa, American Express, Amazon and JetBrains. Most recently John \
       helped develop Datalore, a new data science IDE from JetBrains that \
       suggests context-aware actions to help data scientists with their \
       analyses."
  and joel =
    plain "Joel Krauska" "Protocol Reliability Engineer"
      "Joel builds networks. He loves open source technologies, automation \
       and monitoring large systems at scale. Over the years, he has worked \
       for ISPs, network hardware and software vendors, online gaming \
       companies, consumer electronics, large scale websites and network \
       analytics companies.  He has a MS and BS from the University of \
       Illinois Engineering."
  and paul_steckler =
    plain "Paul Steckler" "Protocol Engineer"
      "Paul is a functional programmer and researcher. In the academic realm, \
       he's followed his interest in PLs, type systems, and formal \
       verification through collaborations with INRIA, the MIT PLV Group, and \
       NICTA. He also worked on the initial implementation of Alacris, a \
       cryptocurrency solution layered on top of existing blockchains. He \
       holds a PhD in computer science from Northeastern University."
  and vanishree =
    plain "Vanishree Rao" "Protocol Researcher"
      "Vanishree is a theoretical and applied cryptographer with deep \
       experience in industry and academia. She earned her PhD at UCLA \
       through her work on zk-proofs, multiparty computation, hashing, and \
       pseudorandom functions, among other projects. She then worked in \
       industry at Xerox PARC and Intertrust Technologies. Vanishree enjoys \
       developing cryptographic solutions for real-world challenges and \
       communicating intuitive explanations of complex cryptography concepts."
  and echo =
    plain "Echo Nolan" "Protocol Engineer"
      "Echo is interested in programming languages, type systems and \
       prediction markets. He has made open source contributions to Idris and \
       various parts of the Haskell ecosystem. He's also made and lost a fair \
       amount of money trading predictions on Augur. Before joining O(1) \
       Labs, Echo worked on an text messaging platform for academic \
       conselors, using functional programming techniques to deliver hundreds \
       of thousands of messages to students."
  and matthew =
    plain "Matthew Ryan" "Protocol Engineer"
      "Matthew Ryan is a self-taught programmer with a strong interest in \
       computer-aided theorem proving, formal program verification, and \
       functional programming. He has been involved with several open-source \
       projects, and passionately believes in the open-source philosophy. He \
       has a BSc in Mathematics from the University of Warwick, U.K., where \
       he studied cryptography."
  and rebekah =
    plain "Rebekah Mercer" "Protocol Researcher"
      "Most recently, Rebekah was a PhD student at Aarhus University, where \
       she was advised by Claudio Orlandi and Ivan Damgård.  Her research \
       revolves around cryptography and privacy, particularly privacy in \
       cryptocurrencies. Rebekah holds an MSc in Information Security from \
       UCL and a BSc in Mathematics from the University of Manchester."
  and jiawei =
    plain "Jiawei Tang" "Protocol Engineer"
      "Jiawei loves writing interpreters and type checkers. He received his \
       BS in computer science from Indiana University, and he's fascinated by \
       categorical semantics and dependent type theory. Currently, he is \
       implementing a toy dependently typed language called Pie."
  and avery =
    plain "Avery Morin" "Protocol Engineer"
      "Avery first encountered OCaml during his BSc in software engineering \
       at McGill University. Since graduating, he's been involved in the \
       ReasonML community in his free time. He's worked on several projects \
       including Reprocessing, a cross-platform port of Processing designed \
       for beginners to the language. Avery is interested in making the \
       helpful aspects of functional programming and type systems more \
       accessible to people who aren’t already taking advantage of them."
  and nacera =
    plain "Nacera Rodstein" "Operations Associate"
      "Nacera has had a career spanning startups, medium sized companies, and \
       corporations. After earning her BS and MS from IAE in Lille, France, \
       Nacera moved to San Francisco. Over the next decade, she worked with \
       Bleacher Report (through growth from 10 to 60 employees and an \
       acquisition by Turner), Mokum Solutions, Sephora, Venture Beat, AMSI, \
       Oracle, and a software sales business which she helped start up and \
       scale."
  and harold =
    plain "Harold Herbert" "Lead Designer"
      "Harold previously designed brands, products, and experiences at Hired, \
       Flipboard, Zillow, and with a range of technology companies while \
       running an independent design studio. He believes that all design is \
       experience design. Regardless of the medium, the end goal is for the \
       well-being of the user."
  and joe =
    advisor "Joseph Bonneau"
      {literal|
Joseph is an assistant professor at NYU. His research has spanned a variety of topics in cryptography and security including HTTPS and web security, passwords and authentication, cryptocurrencies, end-to-end encrypted communication tools, and side-channel cryptanalysis. He is co-author of the popular textbook "Bitcoin and Cryptocurrency Technologies" and co-taught the first MOOC on cryptocurrencies. He holds a PhD from the University of Cambridge and BS and MS degrees in computer science and cryptography from Stanford University.|literal}
  and akis =
    advisor "Akis Kattis"
      "Akis is a PhD candidate in Computer Science at NYU's Courant \
       Institute, where he is advised by Professors Joseph Bonneau and \
       Yevgenyi Dodis. His research revolves around cryptography, privacy, \
       and security, currently focusing on the privacy and scalability issues \
       affecting cryptocurrencies. He also works on differential privacy and \
       its applications to distributed systems and private learning. Akis \
       holds an MSc in theoretical computer science from the University of \
       Toronto and a BSE from Princeton University."
  and benedikt =
    advisor "Benedikt Bünz"
      "Benedikt is a PhD student in the Applied Crypto Group at Stanford and \
       he is advised by Dan Boneh. His research focuses on improving the \
       cryptography of cryptocurrencies. He has done research on zero \
       knowledge proofs (Bulletproofs), verifiable delay functions, super \
       light clients, confidential smart contracts and proofs of solvency."
  and paul_davison =
    advisor "Paul Davison"
      "Paul Davison is the CEO of CoinList - the leading platform for high \
       quality, compliant token sales and airdrops. Prior to CoinList, Paul \
       was the Founder/CEO of Highlight (acquired by Pinterest), an EIR at \
       Benchmark Capital, and a VP at Metaweb (acquired by Google). He holds \
       a BS from Stanford University and an MBA from Stanford Business School."
  and jill =
    let bio =
      {literal|
Jill has worked with the IMF and is an advisor to cryptocurrency and blockchain-based ventures.
Previously, Jill ran strategy at blockchain start up Chain, where she managed
initiatives with Nasdaq and State Street. Jill has conducted academic research
on cryptocurrency at the University of Oxford, where she focused on the economic
and political implications of bitcoin. Jill began her career as a credit trader at Goldman Sachs.
She holds a MSc from Magdalen College, Oxford, and an AB from Harvard, where she studied Classics.
|literal}
    in
    advisor "Jill Carlson" bio
  in
  return
    [ evan
    ; izaak
    ; brad
    ; brandon
    ; corey
    ; deepthi
    ; nathan
    ; john
    ; joel
    ; paul_steckler
    ; vanishree
    ; echo
    ; matthew
    ; rebekah
    ; jiawei
    ; avery
    ; nacera
    ; harold
    ; joe
    ; akis
    ; benedikt
    ; jill
    ; paul_davison ]
