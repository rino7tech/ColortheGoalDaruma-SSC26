# Swift Student Challenge 2026 Submission

## App Playground
> Create an app playground that can be experienced within three minutes.

### Name of your app playground

`ColortheGoalDaruma`

### Upload three screenshots of your app playground that best represent the user experience as .png or .jpg files. Do not upload handwritten notes, sketches, or outlines.

<!-- Add screenshots here -->

### Which software should we use to run your app playground?
`Swift Playgrounds 4.6 or later`

### What problem is your app playground trying to solve and what inspired you to solve it? 200 words or less.

Today is often called an "age of cynicism," where fewer young people openly speak about their aspirations. In Japan, rising rates of youth suicide and depression have become serious social concerns. At the same time, studies suggest that people with clear goals tend to report higher subjective well-being (SWB).

Against this background, I experienced the traditional Japanese ritual of painting the eyes on a Daruma doll for the first time while praying for success in my university entrance exams. Writing my dream on the back of the Daruma allowed me to experience my wish as something real and gave me the resolve to pursue my goal. Ultimately, I was accepted into my desired university.

Through this experience, I realized that defining a goal and acting toward it can itself bring fulfillment and a sense of achievement. Based on this insight, I developed an app that uses the Daruma as a cultural medium to support the transition from setting goals to action, while also conveying the significance of Daruma color traditions.

### Who would benefit from your app playground and how? 200 words or less.

The target users are people who have dreams or goals but struggle to express them clearly in words, as well as those who set goals but forget them in daily life and fail to sustain them. Such users often get stuck at key stages — verbalizing, organizing, and committing — and may never translate intentions into action.

This app supports users by addressing these obstacles step by step. First, during the Daruma color diagnosis, vague goals are broken down through a chat-based interface, helping users clarify what they truly aim for. Next, the result visualizes the goal as a Daruma color, which works as a nonverbal memory hook, making goals easier to recall and helping users maintain awareness over time.

Ultimately, the app helps users move from clarifying their goals to sustaining them in everyday life. Over time, this process is intended to become internalized, supporting continued goal-oriented action, improving subjective well-being, and enabling users to live more purposeful lives.

### How did accessibility factor into your design process? 200 words or less.

Setting goals involves high cognitive demands such as verbalizing, summarizing, and prioritizing ideas. People who struggle with language processing may lose momentum before their thoughts become concrete.

To address this, the app uses a chat-based interface that presents questions step by step. By breaking prompts into smaller parts, users can begin with what they can answer in the moment and gradually refine their goals. When users already have a clear wish, they can write it on the bottom of the Daruma and the app automatically recognizes the text via OCR, reducing input effort.

Because relying only on language increases cognitive load, the app visualizes goals as Daruma colors — which can be grasped more instantly than text and are easier to remember. In addition, click sounds allow users to confirm interactions through hearing even when visual changes are subtle.

Through these choices, the design reduces language and memory burdens, enabling users who struggle with goal setting to move toward action.

### Did you use open source software, other than Swift?
`No`

### Did you use any content that you don't have ownership rights to?
`Yes`

#### You acknowledge and agree that you are solely responsible for the content of your submission. 200 words or less.

The 3D Daruma model was purchased from BOOTH from the creator "3D Ara-monoya" and is used in accordance with its license terms. The shooting-star effect used during the Daruma rotation was purchased from BOOTH from solisnotte (hanamori design) and is used in compliance with its licensing conditions. The tatami background texture and wood-grain assets used in the UI were sourced from Illustration AC and are used in accordance with that service's terms of use.

I take full responsibility for ensuring that all third-party assets included in this submission comply with their respective license conditions and copyright requirements.

### Did you use AI tools?
`Yes`

#### Describe which AI tools you used, what you used them for, and what you learned. 200 words or less.

I incorporated Claude Code and Codex as development support tools. I used them to organize implementation approaches, obtain hints for debugging, and generate small portions of code, reducing the time spent on trial and error.

I did not adopt AI suggestions directly. Instead, I interpreted them in relation to my own design intentions, rewriting or comparing alternatives when necessary. Through this process, I deepened my understanding of state management and view structure to the point where I can explain why certain approaches are appropriate.

Consulting AI also required clearly articulating assumptions, constraints, and intended behavior. In doing so, I often noticed ambiguities in my design and refined the architecture accordingly. As a result, AI improved not only efficiency but also the precision of my design decisions, allowing me to devote more time to user experience design, interface refinement, and overall product quality.

### What other technologies did you use in your app playground, and why did you choose them? 200 words or less.

To present the Daruma as a cultural symbol users can experience rather than a flat illustration, I built it in 3D using SceneKit. Because a Daruma is traditionally a physical object held during prayer, a 2D image could not convey its presence or ritual meaning.

During the diagnosis, I added an animation where Darumas move across the screen like items on a production line, with colors changing in real time. This shows how the result is formed rather than simply presenting it, helping users understand and accept it more naturally.

To recreate the cultural act of painting the Daruma's eye as an authentic experience, I implemented a custom brush shader using Metal. This allows ink diffusion and pressure-sensitive strokes, emphasizing the feeling of writing with a real brush — something PencilKit alone could not achieve.

For users with a clear wish, the app allows direct writing on the back of the Daruma, with text recognized using Vision's `VNRecognizeTextRequest` to determine the appropriate color.

---

## Beyond the Swift Student Challenge
### Have you shared your app development knowledge with others or used your technology skills to support your community? 200 words or less.

Since childhood, I have enjoyed creating things, from building with cardboard to experimenting with video production. I realized that apps are among the creative works that most strongly shape everyday life, which led me to begin developing iOS apps in my second year of high school.

I developed an app called mappy that links places with memories so that visiting a location can vividly recall past emotions and experiences. It won first place in the general development division of App Koshien 2024, a major programming competition for middle and high school students in Japan.

At the programming school I attend, I develop apps alongside peers aiming for the Swift Student Challenge while learning from a previous winner. As one of the more experienced members, I share my knowledge and techniques, helping create an environment where we learn together.

Attending a Swift Student Challenge Winners' event in Marunouchi, where I saw high school students present confidently at the Apple Store, inspired me to pursue the challenge myself — and to become someone who encourages others to take their first step into creativity.

---

## Apps on the App Store (optional)
### Tell us about your apps. 200 words or less.

<!-- Add if applicable -->

---

## Social Media (optional)
### Links to your website or social media. 200 words or less.

<!-- Add if applicable -->

## Comments (optional)
### Is there anything else you'd like us to know?

I am deeply fascinated by the possibilities of technology. The iPhone stands out as a device that many people rely on daily, making it a platform where new products can have a broad impact on society.

Each year, I closely follow the latest technologies announced at Apple's WWDC, excited by the future they open up. Rather than remaining someone who only receives that inspiration, I want to actively use these technologies to create innovative products myself.

Through this aspiration, I decided to apply for the Swift Student Challenge 2026. I hope to continue developing apps that stay close to people's lives and bring new value to everyday experiences.
