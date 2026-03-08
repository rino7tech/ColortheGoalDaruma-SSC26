# Swift Student Challenge 2026 Submission

## App Playground
> Create an app playground that can be experienced within three minutes.

### Name of your app playground

`ColortheGoalDaruma`

### Upload three screenshots of your app playground that best represent the user experience as .png or .jpg files. Do not upload handwritten notes, sketches, or outlines.

<!-- Add screenshots here -->

### Which software should we use to run your app playground?
`Swift Playgrounds 4.6 or later`

### What problem is your app playground trying to solve and what inspired you to solve it?

Today is sometimes described as an "age of cynicism," where fewer young people openly speak about their aspirations. In Japan, rising rates of youth suicide and depression have become serious social concerns. At the same time, studies suggest that people with clear goals tend to report higher subjective well-being (SWB).

Against this background, I experienced the traditional Japanese ritual of painting the eyes on a Daruma doll for the first time while praying for success in my university entrance exams. Writing my dream on the back of the Daruma allowed me to experience my wish as something real and gave me the resolve to pursue my goal. Ultimately, I was accepted into my desired university.

Through this experience, I realized that defining a goal and acting toward it can itself bring fulfillment and a sense of achievement. I came to believe that Daruma culture can play a meaningful role in supporting the process of goal setting and decision-making.

Based on this insight, I developed an app that uses the Daruma as a cultural medium to support the transition from setting goals to action while also conveying the significance of Daruma color traditions.

### Who would benefit from your app playground and how?

The target users are people who have dreams or goals but struggle to express them clearly in words, as well as those who set goals but forget them in daily life and fail to sustain them. Such users often struggle with key stages of goal setting, including verbalizing, organizing, and committing, and may never translate intentions into action.

This app supports users by addressing these obstacles step by step. First, during the Daruma color diagnosis process, vague goals are broken down into smaller ideas and organized, helping users clarify what they truly aim for and reflect on their intentions.

Next, the result visualizes the goal as a Daruma color. This works as a nonverbal cue and memory hook, making goals easier to recall in daily life and helping users maintain awareness and commitment over time.

Ultimately, the app helps users move from clarifying and structuring their goals to sustaining them in everyday life. Over time, this process is intended to become internalized, supporting continued goal-oriented action, improving subjective well-being, and enabling users to live more purposeful and fulfilling lives.

### How did accessibility factor into your design process?

Setting goals involves high cognitive demands such as verbalizing, summarizing, and prioritizing ideas. As a result, people who struggle with language processing may lose momentum before their thoughts become concrete.

To address this, the app does not assume that users can freely describe their goals from the start. Instead, it uses a chat-based interface that presents questions step by step. By breaking prompts into smaller parts, users can begin with what they can answer in the moment and gradually organize their thinking while refining their goals. When users already have a clear wish, the app also allows them to write it on the bottom of the Daruma and automatically recognizes the text, reducing input effort.

Because relying only on language increases cognitive load for understanding and memory, the app visualizes goals as Daruma colors. Colors can be grasped more instantly than text and are easier to remember, providing a complementary nonverbal path to understanding. In addition, click sounds allow users to confirm completion through hearing even when visual changes are subtle.

Through these choices, the design reduces language and memory burdens, enabling users who struggle with goal setting to move toward action.

### Did you use open source software, other than Swift?
`No`

### Did you use any content that you don't have ownership rights to?
`Yes`

The 3D Daruma model was purchased from BOOTH from the creator "3D Ara-monoya" and is used in accordance with its license terms. In addition, the shooting-star effect used during the Daruma rotation was purchased from BOOTH from solisnotte (hanamori design) and is also used in compliance with its licensing conditions.

Furthermore, the tatami background texture and the wood-grain assets used in the UI were sourced from Illustration AC and are used in accordance with that service's terms of use.

I hereby declare that I take full responsibility for ensuring that all third-party assets included in this submission comply with their respective license conditions and copyright requirements.

### Did you use AI tools?
`Yes`

I incorporated Claude Code and Codex as development support tools. I used them to organize implementation approaches, obtain hints for debugging, and generate small portions of code, reducing the time spent on trial and error.

I did not adopt AI suggestions directly. Instead, I interpreted them in relation to my own design intentions, rewriting or comparing alternatives when necessary. Through this process, I reaffirmed Swift's readability and expressive power and deepened my understanding of state management and view structure to the point where I can explain why certain approaches are appropriate.

Consulting AI also required clearly articulating assumptions, constraints, and intended behavior. In doing so, I often noticed ambiguities or gaps in my design and refined the architecture accordingly. As a result, AI improved not only efficiency but also the precision of my design decisions, allowing me to devote more time to user experience design, interface refinement, and overall product quality.

### What other technologies did you use in your app playground, and why did you choose them?

To present the Daruma not merely as an illustration but as a cultural symbol users can experience, I built it in 3D using SceneKit. Because a Daruma is traditionally a physical object held during prayer, I felt a 2D image could not convey its presence or ritual meaning. By recreating its rounded form and texture on the iPad, the design allows users to engage with it in a more tangible way.

During the diagnosis process, I added an animation in which Darumas move across the screen like items on a production line, with their colors changing in real time. This shows how the result is formed rather than simply presenting it, helping users understand and accept it more naturally.

To recreate the cultural act of painting the Daruma's eye as an authentic experience rather than a simple drawing action, I implemented a custom brush shader using Metal. This allows ink diffusion and pressure-sensitive strokes, emphasizing the feeling of writing with a real brush.

For users with a clear wish, the app also allows direct writing on the back of the Daruma. The text is analyzed using Vision's `VNRecognizeTextRequest` to determine the appropriate color.

---

## Beyond the Swift Student Challenge

### Have you shared your app development knowledge with others or used your technology skills to support your community?

Since childhood, I have enjoyed creating things, from building with cardboard to experimenting with video production. Through these experiences, I realized that apps are among the creative works that most strongly shape everyday life, which led me to begin developing iOS apps in my second year of high school.

I developed an app called mappy that links places with memories so that visiting a location can vividly recall past emotions and experiences. The app strengthened communication among friends and won first place in the general development division of App Koshien 2024, a major programming competition for middle and high school students in Japan.

At the programming school I attend, I develop apps with peers aiming for the Swift Student Challenge while learning from a previous winner. As one of the more experienced members, I share my knowledge and techniques, helping create an environment where we learn together.

Attending a Swift Student Challenge Winners' event in Marunouchi, where I saw high school students present at the Apple Store, inspired me to pursue the challenge myself and become someone who encourages others to take their first step into creativity. I hope to contribute to education by sharing my Swift knowledge with learners.

---

## Apps on the App Store

- [mappy](https://apps.apple.com/jp/app/mappy/id6557069354)
- [metpic](https://apps.apple.com/jp/app/metpic/id6741055424)
- [leaply](https://apps.apple.com/jp/app/leaply/id6739790869)
- [mudle](https://apps.apple.com/jp/app/mudle/id6754702924)
- [sukimiru](https://apps.apple.com/jp/app/sukimiru/id6748066512)

---

## Social Media

- X: https://x.com/rino7tech
- GitHub: https://github.com/rino7tech
- Instagram: https://www.instagram.com/r.sy_o7/
- Portfolio: https://rino7.tech/

---

## Comments

I am deeply fascinated by the possibilities of technology. Among them, the iPhone stands out as a device that many people rely on in their daily lives, making it a platform where new products can have a broad impact on society.

Each year, I closely follow the latest technologies announced at Apple's WWDC, and every time I feel excited by the future they open up. However, rather than remaining someone who only receives that inspiration, I began to want to actively use these technologies myself and become someone who creates innovative products.

Through this aspiration, I decided to apply for the Swift Student Challenge 2026. Starting from this challenge, I hope to continue developing apps that stay close to people's lives and bring new value and color to everyday experiences.
