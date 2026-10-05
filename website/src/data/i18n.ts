export type Locale = "en" | "tr";

export const copy = {
  en: {
    language: "English",
    nav: { home: "Home", features: "Features", education: "For Education", screenshots: "Screenshots", about: "About", github: "GitHub", openMenu: "Open navigation menu", closeMenu: "Close navigation menu", language: "Language" },
    footer: { explore: "Explore", project: "Project", source: "Source on GitHub ↗", summary: "An independent open-source project exploring a better classroom Linux experience.", disclaimer: "Independent project · Not affiliated with Ubuntu or any education service" },
    home: {
      title: "AtlasOS", description: "A calmer Linux experience for the classroom. AtlasOS is an education-focused Ubuntu-based Live Linux project.",
      heroEyebrow: "An independent classroom Linux project", heroTitle: "A calmer Linux experience for the classroom.", heroText: "AtlasOS brings a classroom-focused desktop and familiar Linux foundations together in a Live environment shaped around the school day.", explore: "Explore AtlasOS", source: "View source on GitHub ↗", scroll: "Scroll to explore",
      revealEyebrow: "A clear place to begin", revealTitle: "Meet the AtlasOS desktop.", revealText: "A real view of the current Live system, captured as it runs.", desktopAlt: "AtlasOS 0.6.3 Release Candidate Live desktop captured in QEMU/OVMF, showing lesson tools, system status, and today's lesson panel", desktopTitle: "AtlasOS Live desktop", desktopCaption: "A genuine 0.6.3 Release Candidate capture from a UEFI QEMU session.",
      storyLabel: "The AtlasOS desktop experience", storyPhotoLabel: "AtlasOS Live desktop", storyVersion: "0.6.3 RC · QEMU/OVMF capture", story: [
        { eyebrow: "01 · Made for the room", title: "Built around the classroom.", text: "A home screen brings lesson tools and system information into a familiar starting place." },
        { eyebrow: "02 · The everyday tools", title: "Teaching tools, close at hand.", text: "Shortcuts for common classroom tasks sit beside access to the wider Linux desktop." },
        { eyebrow: "03 · Room to focus", title: "Less searching. More teaching.", text: "AtlasOS explores a clearer way to find the next useful action on a shared classroom screen." },
      ],
      classroomEyebrow: "Designed with interactive classrooms in mind", classroomTitle: "A bigger screen deserves a clearer rhythm.", classroomText: "AtlasOS is designed around readable layouts, direct navigation, and touch-friendly thinking. Device support is still being evaluated.", classroomPoints: ["Clear paths to lesson tools", "Visible sound, network, and display state", "A familiar Linux desktop underneath"], classroomAlt: "Actual AtlasOS 0.6.3 Release Candidate desktop shown in a presentation frame", classroomCaption: "Presentation framing around a real AtlasOS capture · not a classroom photograph",
      bootEyebrow: "Before the desktop", bootTitle: "A boot experience built for AtlasOS.", bootText: "The Atlas Boot Manager is a UEFI frontend created for the project. Here is its real menu capture.", bootLink: "See the product captures →", bootAlt: "AtlasOS Boot Manager showing Start AtlasOS Live, Advanced Options, Start from Disk, and System Tools", bootCaption: "A real boot-menu capture. Firmware appearance can vary by device.",
      principlesEyebrow: "A few guiding ideas", principlesTitle: "Technology should make the lesson feel simpler.", principles: [
        { title: "Education first", text: "Start with the routines and tools that make up a classroom day." },
        { title: "Focused interface", text: "Make common actions easier to find, while keeping the desktop flexible." },
        { title: "Open source", text: "Keep project code and decisions available for people to inspect." },
        { title: "Designed for large displays", text: "Think about readability and touch from the start; validate support device by device." },
      ],
      openEyebrow: "Built in the open", openTitle: "See how AtlasOS is taking shape.", openText: "Read the source, explore the architecture, and follow the project as it develops.",
      finalEyebrow: "A project in progress", finalTitle: "The classroom deserves software built with it in mind.", finalText: "Follow the work, explore the real product captures, and see what comes next.", finalGallery: "View current product captures",
    },
    features: {
      title: "Features", description: "Explore the AtlasOS desktop, education workflows, diagnostics, and custom UEFI boot frontend.", eyebrow: "The Atlas experience", heroTitle: "A Linux environment shaped around the lesson.", heroText: "AtlasOS brings classroom-oriented navigation and system controls to familiar Linux foundations. The project is actively developing, and each capability has a clearly documented scope.",
      rows: [
        { eyebrow: "01 · Before class begins", title: "A clear starting point for the day.", text: "The Atlas desktop places teaching shortcuts and device status in view, while leaving the wider Linux environment available.", link: "View the actual desktop capture →", imageAlt: "Real AtlasOS Live desktop with classroom navigation, resources, lesson tools, and system status", imageTitle: "AtlasOS Live desktop", caption: "A genuine capture from the 0.6.3 Release Candidate running in QEMU/OVMF.", image: "/AtlasOS/images/product/atlasos-desktop-0.6.3-rc.webp" },
        { eyebrow: "02 · A distinct boot identity", title: "An Atlas welcome before Linux starts.", text: "The Rust UEFI frontend presents AtlasOS boot choices and starts the documented backend in the normal validated path.", link: "View the actual boot capture →", imageAlt: "Real AtlasOS Boot Manager menu", imageTitle: "Atlas Boot Manager", caption: "A genuine boot-menu capture. Firmware appearance can vary by device.", image: "/AtlasOS/images/atlasos-boot-manager.png" },
      ], boundaryEyebrow: "Designed for evaluation", boundary: "AtlasOS currently provides a USB-bootable Live environment. It does not include an installer or an in-place upgrade path. Hardware support remains under evaluation.",
    },
    education: {
      title: "For Education", description: "Why AtlasOS is being built for classroom teachers and interactive-board environments.", eyebrow: "For the people in the room", heroTitle: "Built around the classroom day.", heroText: "AtlasOS is an independent project exploring a practical Live Linux environment for teachers, students, and the teams who support classroom devices.",
      sectionEyebrow: "A classroom-minded direction", sectionTitle: "Designed for real classroom routines.", sectionText: "The goal is a focused environment that makes common actions easier to find while keeping the flexibility of Linux available to technical teams.", principles: [
        { title: "Designed for interactive boards", text: "Readable layouts and touch-oriented use are part of the project direction; device compatibility is still being evaluated." },
        { title: "Simple for teachers", text: "A lesson-first home and direct shortcuts aim to reduce the steps between starting the system and opening a tool." },
        { title: "Familiar for students", text: "A clear, consistent interface is intended to make shared classroom devices easier to approach." },
      ],
      imageAlt: "AtlasOS 0.6.3 Release Candidate Live desktop showing lesson tools and classroom resources", imageTitle: "A classroom-oriented Live desktop", imageCaption: "A genuine virtual UEFI capture from the current Release Candidate.",
      nextEyebrow: "A better classroom experience", nextTitle: "Useful today, honest about what comes next.", nextText1: "AtlasOS currently provides a Live desktop, teaching-oriented shortcuts, and diagnostics tools. An installer, centralized device administration, class profiles, offline content delivery, and official education-service integration are not established capabilities.", nextText2: "Physical validation is currently limited to a single owner-reported device. The project continues to document what has been tested and what remains open.", ctaTitle: "Follow the work in the open.", ctaText: "Read the roadmap and source to see how the project is progressing.", cta: "View the roadmap ↗",
    },
    screenshots: {
      title: "Screenshots", description: "Authentic AtlasOS product captures from its desktop and UEFI boot experience.", eyebrow: "Current AtlasOS captures", heroTitle: "The product, as it is.", heroText: "These images are genuine captures from AtlasOS. Each caption identifies the version and whether it was captured in a virtual or physical environment.",
      captures: [
        { image: "/AtlasOS/images/product/atlasos-desktop-0.6.3-rc.webp", alt: "AtlasOS 0.6.3 Release Candidate desktop showing classroom navigation, teaching shortcuts, lesson schedule, and system status", title: "AtlasOS Live desktop", caption: "0.6.3 Release Candidate · virtual UEFI capture in QEMU/OVMF · 1920 × 1080.", kind: "desktop", width: 1920, height: 1080 },
        { image: "/AtlasOS/images/atlasos-boot-manager.png", alt: "Actual AtlasOS Boot Manager menu with Live, Advanced Options, Start from Disk, and System Tools", title: "Atlas Boot Manager", caption: "Actual boot-menu capture. Firmware appearance can vary by device.", kind: "boot", width: 1600, height: 900 },
        { image: "/AtlasOS/images/atlasos-live-desktop.jpeg", alt: "AtlasOS 0.6.2 desktop with classroom navigation, lesson tools, system status, and lesson schedule", title: "AtlasOS 0.6.2 desktop", caption: "Historical product capture from 0.6.2 · the screen itself is a real AtlasOS session.", kind: "desktop", width: 1600, height: 900 },
      ], footnote: "Product imagery shows real AtlasOS captures. Presentation framing is decorative; it does not add or alter interface content.",
    },
    about: {
      title: "About", description: "Learn about the goals, principles, and technology behind the independent AtlasOS project.", eyebrow: "An independent open project", heroTitle: "About AtlasOS.", heroText: "AtlasOS explores a more classroom-oriented experience on top of established Linux technology — shaped for teaching workflows and interactive-board environments.",
      goalEyebrow: "Our goal", goalTitle: "Make classroom computing feel more focused.", goal1: "AtlasOS began with a practical question: could a Live Linux environment help teachers get to the tools they use in class with less friction?", goal2: "The answer is being explored through a custom desktop, system integration, and an Atlas-specific UEFI boot frontend. The project is early, and usability research and broad device qualification remain future work.", goalLink: "Explore the source ↗", independent: "Independent project", aside: "Built around a simple idea: make classroom computing feel more focused.",
      stackEyebrow: "Technology stack", stackTitle: "Built on familiar foundations.", stackText: "AtlasOS integrates selected upstream projects and services rather than replacing their work.", stack: ["Ubuntu Live", "Linux kernel", "Qt 6 / QML", "Python / PySide6", "Rust UEFI app", "GRUB backend", "Plymouth", "XFCE session"],
      openEyebrow: "Open and transparent", openTitle: "Built in the open, with clear limits.", openText: "AtlasOS-owned source is available under the MIT License. Third-party packages and assets retain their own licensing terms. The project does not claim official affiliation with Canonical, Ubuntu, or education services.", benefitTitle: "Continuously improving", benefitText: "Build notes, validation scope, known limitations, and future work are recorded alongside the source.", benefitLink: "See the roadmap →",
    },
    download: {
      title: "Download", description: "AtlasOS source is available on GitHub. A public binary release is still being prepared.", eyebrow: "Try AtlasOS", heroTitle: "The source is open. The ISO is being prepared.", heroText: "The AtlasOS source repository is public. The project does not currently offer an approved public ISO download; binary release remains on hold while release checks are completed.",
      statusEyebrow: "Binary release status", statusTitle: "Public ISO release is in preparation.", statusText: "There is no approved ISO download yet. Historical validation images are not public release assets. We will publish a downloadable image through GitHub Releases after the current candidate completes its release review.", source: "View source on GitHub ↗", releases: "Check release page ↗", note: "The release page may not contain an AtlasOS binary today. Do not use historical local test images as public downloads.", nextEyebrow: "When a release is ready", nextTitle: "Clear files, clear verification.", nextText: "A future release will include a named ISO, SHA-256 checksum, validation summary, and known limitations so you can verify what you download and understand what has been tested.",
    },
    community: {
      title: "Community", description: "Join the open AtlasOS project on GitHub, explore its code, and report reproducible issues.", eyebrow: "The project is open", heroTitle: "Be part of the work.", heroText: "AtlasOS is built in public. Explore how it works, follow project decisions, and share specific feedback through the repository.",
      cards: [
        { title: "GitHub repository ↗", text: "Browse AtlasOS source code, project documentation, and development history.", key: "repo" },
        { title: "Report an issue ↗", text: "Share a reproducible bug report or suggest a focused improvement.", key: "issues" },
        { title: "Project roadmap ↗", text: "Read what is implemented, what is being explored, and what remains planned.", key: "roadmap" },
      ], helpful: "Helpful reports", helpfulTitle: "Details make feedback actionable.", helpfulText: "For a technical report, include the AtlasOS version, device model, CPU/GPU, boot mode, display resolution, Live or installed state, and steps to reproduce. Please leave out serial numbers, MAC addresses, student information, and other private identifiers.", ctaTitle: "Start with the code.", ctaText: "AtlasOS is an independent project, developed openly on GitHub.", cta: "Open AtlasOS on GitHub ↗",
    },
    notFound: { title: "Page not found", description: "The page you requested could not be found on AtlasOS.", heading: "This page wandered off.", text: "The page may have moved or the link may be out of date. Let’s get you back to the AtlasOS home page.", home: "Go to home" },
  },
  tr: {
    language: "Türkçe",
    nav: { home: "Ana sayfa", features: "Özellikler", education: "Eğitim için", screenshots: "Ekran görüntüleri", about: "Hakkında", github: "GitHub", openMenu: "Gezinme menüsünü aç", closeMenu: "Gezinme menüsünü kapat", language: "Dil" },
    footer: { explore: "Keşfet", project: "Proje", source: "GitHub kaynak kodu ↗", summary: "Sınıflar için daha iyi bir Linux deneyimini araştıran bağımsız, açık kaynaklı bir proje.", disclaimer: "Bağımsız proje · Ubuntu veya herhangi bir eğitim hizmetiyle bağlantılı değildir" },
    home: {
      title: "AtlasOS", description: "Sınıflar için daha sade bir Linux deneyimi. AtlasOS, eğitime odaklanan Ubuntu tabanlı bir Live Linux projesidir.",
      heroEyebrow: "Bağımsız bir sınıf Linux projesi", heroTitle: "Sınıflar için daha sade bir Linux deneyimi.", heroText: "AtlasOS, sınıf kullanımına odaklanan bir masaüstünü Linux’un tanıdık temelleriyle bir araya getiriyor. Live ortamı, okul günündeki ihtiyaçlar düşünülerek geliştiriliyor.", explore: "AtlasOS’u keşfet", source: "GitHub’da kaynak kodu ↗", scroll: "Keşfetmek için kaydır",
      revealEyebrow: "Güne başlamak için açık bir alan", revealTitle: "AtlasOS masaüstüyle tanışın.", revealText: "Çalışır durumdaki güncel Live sisteminden gerçek bir görüntü.", desktopAlt: "Ders araçlarını, sistem durumunu ve günlük ders programını gösteren AtlasOS 0.6.3 Release Candidate Live masaüstü; QEMU/OVMF üzerinde yakalanmıştır", desktopTitle: "AtlasOS Live masaüstü", desktopCaption: "UEFI QEMU oturumunda çalışan 0.6.3 Release Candidate sürümünden gerçek görüntü.",
      storyLabel: "AtlasOS masaüstü deneyimi", storyPhotoLabel: "AtlasOS Live masaüstü", storyVersion: "0.6.3 RC · QEMU/OVMF görüntüsü", story: [
        { eyebrow: "01 · Sınıf için", title: "Sınıf düzenine göre tasarlandı.", text: "Ders araçları ve sistem bilgileri, güne alışıldık bir başlangıç ekranıyla başlamanızı sağlar." },
        { eyebrow: "02 · Günlük araçlar", title: "Ders araçları elinizin altında.", text: "Sık kullanılan sınıf işleri için kısayollar, Linux masaüstüne erişimle yan yana durur." },
        { eyebrow: "03 · Derse odaklanın", title: "Daha az arayın, daha çok öğretin.", text: "AtlasOS, ortak kullanılan sınıf ekranında sıradaki işe daha kolay ulaşmanın yollarını araştırıyor." },
      ],
      classroomEyebrow: "Etkileşimli sınıflar düşünülerek tasarlanıyor", classroomTitle: "Büyük ekranlar için daha anlaşılır bir düzen.", classroomText: "AtlasOS okunaklı yerleşimleri, doğrudan gezinmeyi ve dokunmatik kullanımı gözetiyor. Cihaz uyumluluğu değerlendirilmeye devam ediyor.", classroomPoints: ["Ders araçlarına açık erişim", "Ses, ağ ve ekran durumunun görünürlüğü", "Alışıldık Linux masaüstü temeli"], classroomAlt: "Sunum çerçevesinde gösterilen gerçek AtlasOS 0.6.3 Release Candidate masaüstü", classroomCaption: "Gerçek AtlasOS görüntüsü sunum çerçevesinde gösteriliyor · sınıf fotoğrafı değildir",
      bootEyebrow: "Masaüstünden önce", bootTitle: "AtlasOS için tasarlanmış bir açılış deneyimi.", bootText: "Atlas Boot Manager, proje için geliştirilen bir UEFI arayüzüdür. Burada menünün gerçek görüntüsünü görebilirsiniz.", bootLink: "Ürün görüntülerini inceleyin →", bootAlt: "AtlasOS Boot Manager menüsünde AtlasOS Live’ı Başlat, Gelişmiş Seçenekler, Diskten Başlat ve Sistem Araçları seçenekleri", bootCaption: "Gerçek açılış menüsü görüntüsü. Görünüm cihazın firmware’ine göre değişebilir.",
      principlesEyebrow: "Birkaç temel yaklaşım", principlesTitle: "Teknoloji, dersi daha anlaşılır kılmalı.", principles: [
        { title: "Önce eğitim", text: "Sınıf gününü oluşturan rutinlerden ve araçlardan başlayın." },
        { title: "Odaklı arayüz", text: "Masaüstünün esnekliğini korurken sık kullanılan işleri kolay bulunur kılın." },
        { title: "Açık kaynak", text: "Proje kodunu ve kararlarını herkesin incelemesine açık tutun." },
        { title: "Büyük ekranlara uygun", text: "Okunabilirliği ve dokunmatik kullanımı en baştan düşünün; uyumluluğu her cihazda ayrı doğrulayın." },
      ],
      openEyebrow: "Açık geliştirme", openTitle: "AtlasOS’un gelişimini takip edin.", openText: "Kaynak kodunu inceleyin, mimariyi keşfedin ve proje ilerledikçe gelişmeleri izleyin.",
      finalEyebrow: "Geliştirme sürüyor", finalTitle: "Sınıflar, ihtiyaçları düşünülerek geliştirilmiş yazılımları hak ediyor.", finalText: "Gelişmeleri takip edin, gerçek ürün görüntülerini inceleyin ve sırada ne olduğunu görün.", finalGallery: "Güncel ürün görüntüleri",
    },
    features: {
      title: "Özellikler", description: "AtlasOS masaüstünü, eğitim iş akışlarını, tanılama araçlarını ve özel UEFI açılış arayüzünü keşfedin.", eyebrow: "Atlas deneyimi", heroTitle: "Dersin akışına göre şekillenen bir Linux ortamı.", heroText: "AtlasOS, sınıf kullanımına yönelik gezinme ve sistem denetimlerini Linux’un tanıdık temelleriyle bir araya getiriyor. Proje geliştirme aşamasında; her özelliğin kapsamı açıkça belirtiliyor.",
      rows: [
        { eyebrow: "01 · Ders başlamadan önce", title: "Gün için anlaşılır bir başlangıç.", text: "Atlas masaüstü, öğretmen araçlarını ve cihaz durumunu görünür tutarken Linux ortamının geri kalanına da erişim sağlar.", link: "Gerçek masaüstü görüntüsünü inceleyin →", imageAlt: "Sınıf gezinmesini, kaynakları, ders araçlarını ve sistem durumunu gösteren gerçek AtlasOS Live masaüstü", imageTitle: "AtlasOS Live masaüstü", caption: "QEMU/OVMF üzerinde çalışan 0.6.3 Release Candidate sürümünden gerçek görüntü.", image: "/AtlasOS/images/product/atlasos-desktop-0.6.3-rc.webp" },
        { eyebrow: "02 · Kendine özgü açılış", title: "Linux başlamadan önce Atlas karşılaması.", text: "Rust ile geliştirilen UEFI arayüzü, AtlasOS açılış seçeneklerini sunar ve normal doğrulanmış akışta belgelenen arka ucu başlatır.", link: "Gerçek açılış menüsünü inceleyin →", imageAlt: "Gerçek AtlasOS Boot Manager menüsü", imageTitle: "Atlas Boot Manager", caption: "Gerçek açılış menüsü görüntüsü. Görünüm cihazın firmware’ine göre değişebilir.", image: "/AtlasOS/images/atlasos-boot-manager.png" },
      ], boundaryEyebrow: "Değerlendirme aşamasında", boundary: "AtlasOS şu anda USB’den başlatılabilen bir Live ortamı sunuyor. Kurulum aracı veya mevcut sistemi yerinde yükseltme yolu bulunmuyor. Donanım uyumluluğu değerlendirilmeye devam ediyor.",
    },
    education: {
      title: "Eğitim için", description: "AtlasOS’un öğretmenler ve etkileşimli tahta ortamları için neden geliştirildiğini öğrenin.", eyebrow: "Sınıftaki herkes için", heroTitle: "Sınıf gününün akışına göre geliştiriliyor.", heroText: "AtlasOS; öğretmenler, öğrenciler ve sınıf cihazlarını destekleyen ekipler için kullanışlı bir Live Linux ortamını araştıran bağımsız bir projedir.",
      sectionEyebrow: "Sınıfı gözeten bir yaklaşım", sectionTitle: "Sınıftaki gerçek rutinler düşünülerek tasarlanıyor.", sectionText: "Amaç, teknik ekiplerin Linux esnekliğinden yararlanmaya devam edebilmesiyle birlikte sık kullanılan işleri kolay bulunur kılan odaklı bir ortam sunmak.", principles: [
        { title: "Etkileşimli tahtalar için", text: "Okunaklı yerleşimler ve dokunmatik kullanım proje yönünün parçası; cihaz uyumluluğu hâlâ değerlendiriliyor." },
        { title: "Öğretmenler için kolay", text: "Ders odaklı ana ekran ve doğrudan kısayollar, sistemi açtıktan sonra araca ulaşmak için gereken adımları azaltmayı hedefliyor." },
        { title: "Öğrenciler için tanıdık", text: "Tutarlı ve anlaşılır bir arayüz, ortak kullanılan sınıf cihazlarına alışmayı kolaylaştırmayı amaçlıyor." },
      ],
      imageAlt: "Ders araçlarını ve sınıf kaynaklarını gösteren AtlasOS 0.6.3 Release Candidate Live masaüstü", imageTitle: "Sınıf kullanımına yönelik Live masaüstü", imageCaption: "Güncel Release Candidate sürümünden gerçek sanal UEFI görüntüsü.",
      nextEyebrow: "Daha iyi bir sınıf deneyimi", nextTitle: "Bugün işe yarayanı gösterin, sıradakiler konusunda açık olun.", nextText1: "AtlasOS şu anda Live masaüstü, öğretim odaklı kısayollar ve tanılama araçları sunuyor. Kurulum aracı, merkezi cihaz yönetimi, sınıf profilleri, çevrimdışı içerik dağıtımı ve resmî eğitim hizmeti entegrasyonu mevcut özellikler değildir.", nextText2: "Fiziksel doğrulama şu an için proje sahibinin bildirdiği tek bir cihazla sınırlıdır. Proje, test edilenleri ve açık kalan noktaları kaydetmeyi sürdürüyor.", ctaTitle: "Geliştirmeyi açıkça takip edin.", ctaText: "Projenin ilerleyişini yol haritasından ve kaynak kodundan inceleyin.", cta: "Yol haritası ↗",
    },
    screenshots: {
      title: "Ekran görüntüleri", description: "AtlasOS masaüstü ve UEFI açılış deneyiminden gerçek ürün görüntüleri.", eyebrow: "Güncel AtlasOS görüntüleri", heroTitle: "Ürünün bugünkü hâli.", heroText: "Bu görseller AtlasOS çalışırken alınmıştır. Her açıklamada sürüm ve görüntünün sanal ya da fiziksel ortamda alındığı belirtilir.",
      captures: [
        { image: "/AtlasOS/images/product/atlasos-desktop-0.6.3-rc.webp", alt: "Sınıf gezinmesini, öğretmen kısayollarını, ders programını ve sistem durumunu gösteren AtlasOS 0.6.3 Release Candidate masaüstü", title: "AtlasOS Live masaüstü", caption: "0.6.3 Release Candidate · QEMU/OVMF üzerinde sanal UEFI görüntüsü · 1920 × 1080.", kind: "desktop", width: 1920, height: 1080 },
        { image: "/AtlasOS/images/atlasos-boot-manager.png", alt: "Live, Gelişmiş Seçenekler, Diskten Başlat ve Sistem Araçları seçeneklerini gösteren gerçek AtlasOS Boot Manager menüsü", title: "Atlas Boot Manager", caption: "Gerçek açılış menüsü görüntüsü. Görünüm cihazın firmware’ine göre değişebilir.", kind: "boot", width: 1600, height: 900 },
        { image: "/AtlasOS/images/atlasos-live-desktop.jpeg", alt: "Sınıf gezinmesini, ders araçlarını, sistem durumunu ve programı gösteren AtlasOS 0.6.2 masaüstü", title: "AtlasOS 0.6.2 masaüstü", caption: "0.6.2’den tarihî ürün görüntüsü · ekrandaki arayüz gerçek AtlasOS oturumudur.", kind: "desktop", width: 1600, height: 900 },
      ], footnote: "Ürün görselleri gerçek AtlasOS görüntüleridir. Sunum çerçevesi dekoratiftir; arayüz içeriğini değiştirmez.",
    },
    about: {
      title: "Hakkında", description: "Bağımsız AtlasOS projesinin amaçlarını, ilkelerini ve kullandığı teknolojileri öğrenin.", eyebrow: "Bağımsız ve açık bir proje", heroTitle: "AtlasOS hakkında.", heroText: "AtlasOS, öğretim iş akışları ve etkileşimli tahta ortamları düşünülerek, yerleşik Linux teknolojileri üzerinde sınıf kullanımına daha uygun bir deneyim araştırıyor.",
      goalEyebrow: "Amacımız", goalTitle: "Sınıfta bilgisayar kullanımını daha odaklı hâle getirmek.", goal1: "AtlasOS pratik bir soruyla başladı: Live Linux ortamı öğretmenlerin sınıfta kullandıkları araçlara daha az uğraşla ulaşmasına yardımcı olabilir mi?", goal2: "Bu soru özel bir masaüstü, sistem entegrasyonu ve Atlas’a özgü UEFI açılış arayüzüyle araştırılıyor. Proje henüz erken aşamada; kullanılabilirlik araştırmaları ve geniş cihaz doğrulaması ileride yapılacak işler arasında.", goalLink: "Kaynak kodunu inceleyin ↗", independent: "Bağımsız proje", aside: "Sınıfta bilgisayar kullanımını daha odaklı hâle getirme fikriyle geliştiriliyor.",
      stackEyebrow: "Teknoloji altyapısı", stackTitle: "Tanıdık temeller üzerinde.", stackText: "AtlasOS, diğer projelerin yerini almak yerine seçili açık kaynaklı projeleri ve servisleri bir araya getirir.", stack: ["Ubuntu Live", "Linux çekirdeği", "Qt 6 / QML", "Python / PySide6", "Rust UEFI uygulaması", "GRUB arka ucu", "Plymouth", "XFCE oturumu"],
      openEyebrow: "Açık ve şeffaf", openTitle: "Geliştirme açık, sınırlar net.", openText: "AtlasOS’un kendi kaynak kodu MIT Lisansı ile yayımlanır. Üçüncü taraf paketler ve varlıklar kendi lisans koşullarına tabidir. Proje Canonical, Ubuntu veya eğitim hizmetleriyle resmî bağlantı iddiasında bulunmaz.", benefitTitle: "Geliştirme sürüyor", benefitText: "Derleme notları, doğrulama kapsamı, bilinen sınırlamalar ve sonraki işler kaynak koduyla birlikte kaydediliyor.", benefitLink: "Yol haritasına göz atın →",
    },
    download: {
      title: "İndirme", description: "AtlasOS kaynak kodu GitHub’da açık. Herkese açık ikili sürüm hazırlık aşamasında.", eyebrow: "AtlasOS’u deneyin", heroTitle: "Kaynak kodu açık. ISO hazırlık aşamasında.", heroText: "AtlasOS kaynak deposu herkese açıktır. Sürüm kontrolleri tamamlanana kadar onaylanmış bir herkese açık ISO indirmesi sunulmuyor.",
      statusEyebrow: "İkili sürüm durumu", statusTitle: "Herkese açık ISO hazırlanıyor.", statusText: "Henüz onaylanmış bir ISO indirmesi yok. Tarihî doğrulama görüntüleri herkese açık sürüm dosyaları değildir. Güncel aday sürüm, sürüm incelemesini tamamladıktan sonra indirme dosyası GitHub Releases üzerinden sunulacak.", source: "GitHub’da kaynak kodu ↗", releases: "Sürüm sayfası ↗", note: "Sürüm sayfasında şu anda AtlasOS ikili dosyası bulunmayabilir. Yerel testler için kullanılan tarihî görüntüleri herkese açık indirme olarak kullanmayın.", nextEyebrow: "Sürüm hazır olduğunda", nextTitle: "Açık dosyalar, doğrulanabilir içerik.", nextText: "Gelecek bir sürüm; adlandırılmış ISO, SHA-256 özeti, doğrulama özeti ve bilinen sınırlamalarla birlikte sunulacak. Böylece indirilen dosyayı ve hangi testlerden geçtiğini doğrulayabilirsiniz.",
    },
    community: {
      title: "Topluluk", description: "Açık AtlasOS projesine GitHub üzerinden katılın, kodu inceleyin ve tekrarlanabilir sorunları bildirin.", eyebrow: "Proje herkese açık", heroTitle: "Geliştirmeye katılın.", heroText: "AtlasOS açık olarak geliştiriliyor. Nasıl çalıştığını inceleyin, proje kararlarını takip edin ve depoda somut geri bildirim paylaşın.",
      cards: [
        { title: "GitHub deposu ↗", text: "AtlasOS kaynak koduna, proje belgelerine ve geliştirme geçmişine göz atın.", key: "repo" },
        { title: "Sorun bildirin ↗", text: "Tekrarlanabilir hata bildirin veya belirli bir iyileştirme önerin.", key: "issues" },
        { title: "Proje yol haritası ↗", text: "Nelerin hazır olduğunu, nelerin araştırıldığını ve nelerin planlandığını görün.", key: "roadmap" },
      ], helpful: "Yararlı bildirimler", helpfulTitle: "Ayrıntılar geri bildirimi işe yarar kılar.", helpfulText: "Teknik bildirimlerde AtlasOS sürümünü, cihaz modelini, CPU/GPU bilgisini, açılış modunu, ekran çözünürlüğünü, Live veya kurulu sistem durumunu ve tekrarlama adımlarını paylaşın. Seri numarası, MAC adresi, öğrenci bilgisi ve diğer özel tanımlayıcıları eklemeyin.", ctaTitle: "Kodla başlayın.", ctaText: "AtlasOS, GitHub’da açık biçimde geliştirilen bağımsız bir projedir.", cta: "AtlasOS’u GitHub’da açın ↗",
    },
    notFound: { title: "Sayfa bulunamadı", description: "İstenen AtlasOS sayfası bulunamadı.", heading: "Bu sayfa yerini kaybetmiş.", text: "Sayfa taşınmış veya bağlantı güncelliğini yitirmiş olabilir. AtlasOS ana sayfasına dönelim.", home: "Ana sayfaya dön" },
  },
} as const;

export function localeFromPath(pathname: string): Locale {
  return /(?:^|\/)tr(?:\/|$)/.test(pathname.replace(/^\/AtlasOS/, "")) ? "tr" : "en";
}

export function localizedPath(pathname: string, target: Locale): string {
  const path = pathname.replace(/^\/AtlasOS/, "") || "/";
  if (path === "/404.html" || path === "/404/" || path === "/tr/404/" || path === "/tr/404") return target === "tr" ? "/AtlasOS/tr/404/" : "/AtlasOS/404.html";
  const englishPath = path.replace(/^\/tr(?=\/|$)/, "") || "/";
  if (target === "en") return `/AtlasOS${englishPath}`;
  return `/AtlasOS/tr${englishPath === "/" ? "/" : englishPath}`;
}
