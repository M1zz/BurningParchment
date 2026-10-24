// DebugLaunch.swift
// DEBUG 빌드에서만 쓰는 실행 인자 — 시뮬레이터에서 프로 화면을 확인하고 스크린샷을 찍기 위한 것.
//
//   -forcePro YES|NO       프로 권한을 강제로 켜거나 끈다 (지정 안 하면 실제 구매를 따른다)
//   -seedDemo YES          기록이 하나도 없을 때만 지난 1년치 예시 회고와 조각을 채운다
//   -debugScreen <이름>     실행하자마자 그 화면을 띄운다
//                          paywall · settings · fragments · poster · card · book · bookExport · insights
//   -parchmentStyle <값>    classic · moonlit · celadon · dusk (@AppStorage 를 그대로 덮는다)
//   -flameKind <값>         classic · blaze · smolder · sparkler (불꽃의 종류, 마찬가지로 덮는다)
//   -skipNotifications YES  알림 권한 요청·예약과 실시간 현황을 건너뛴다 (스크린샷용. 새 시뮬레이터에서 멈춤도 막는다)
//   -demoProgress 0.45      지금 이 비율만큼 탄 하루가 되도록 기상·취침 시각을 맞춘다 (깨어 있는 시간 16시간)
//                          ⚠️ 앱 그룹의 기상·취침 설정을 덮어쓴다 — 스크린샷용 시뮬레이터에서만 쓸 것
//   -demoSchedule 7:00-23:00 기상·취침 시각을 이 값으로 덮는다 (설정 화면 스크린샷용)
//   -period week|month|year 그 기간 페이지로 연다
//   debugScreen 에 urn(재 항아리) · year · blowout · freeTime(자유시간 정하기) · flames(불꽃 종류 캐러셀) 도 있다
//   -freeTimeDemo YES       자유시간이 비어 있으면 평일 저녁·주말 오후 예시를 넣고 자유시간 탭을 연다
//
// 예) xcrun simctl launch booted com.burningparchment.app -forcePro YES -seedDemo YES -debugScreen insights

import SwiftUI

#if DEBUG
enum DebugLaunch {
    static var forcePro: Bool? {
        UserDefaults.standard.object(forKey: "forcePro") == nil ? nil : UserDefaults.standard.bool(forKey: "forcePro")
    }
    static var seedDemo: Bool { UserDefaults.standard.bool(forKey: "seedDemo") }
    static var skipNotifications: Bool { UserDefaults.standard.bool(forKey: "skipNotifications") }

    /// 매니저들이 만들어지기 전에(App.init) 불러야 한다.
    static func applyOverrides() {
        // 스크린샷·UI 시험: 처음 안내와 새 소식을 이미 본 것으로 둔다
        if UserDefaults.standard.bool(forKey: "skipOnboarding") {
            UserDefaults.standard.set(true, forKey: LaunchAudience.onboardingKey)
            UserDefaults.standard.set(WhatsNewContent.version, forKey: LaunchAudience.whatsNewKey)
        }
        // -demoSchedule 7:00-23:00 — 설정 화면 스크린샷용. 찍는 시각과 상관없이 자연스러운 기상·취침 시각을 넣는다.
        if let schedule = UserDefaults.standard.string(forKey: "demoSchedule") {
            let parts = schedule.split(separator: "-").map { $0.split(separator: ":").compactMap { Int($0) } }
            if parts.count == 2, parts[0].count == 2, parts[1].count == 2 {
                let sd = UserDefaults(suiteName: "group.com.burningparchment.app")
                sd?.set(parts[0][0], forKey: "wakeHour")
                sd?.set(parts[0][1], forKey: "wakeMinute")
                sd?.set(parts[1][0], forKey: "bedtimeHour")
                sd?.set(parts[1][1], forKey: "bedtimeMinute")
            }
        }
        guard let raw = UserDefaults.standard.string(forKey: "demoProgress"),
              let progress = Double(raw) else { return }
        let awake: TimeInterval = 16 * 3600
        let wake = Date().addingTimeInterval(-awake * progress)
        let bed = wake.addingTimeInterval(awake)
        let cal = Calendar.current
        let sd = UserDefaults(suiteName: "group.com.burningparchment.app")
        sd?.set(cal.component(.hour, from: wake), forKey: "wakeHour")
        sd?.set(cal.component(.minute, from: wake), forKey: "wakeMinute")
        sd?.set(cal.component(.hour, from: bed), forKey: "bedtimeHour")
        sd?.set(cal.component(.minute, from: bed), forKey: "bedtimeMinute")
    }

    /// 예시 회고 글(10개)과 조각 문구(9개, 빈 칸 포함) — 스크린샷 화면이 그 언어로만 보이도록 언어마다 따로 쓴다.
    private static let demoTexts: [String: (texts: [String], phrases: [String])] = [
        "en": (["Walked for 30 minutes this morning", "Finished the first draft of the report",
                "Watched videos for two hours", "Didn't read a single page", "Had a long call with a friend",
                "Put off the gym again", "Cooked dinner myself", "Scrolled shopping apps for no reason",
                "Left work early and took a walk", "Mapped out the new project"],
               ["That's enough for today", "A little earlier tomorrow", "I did enough", "", "A warm evening",
                "", "Open a book next time", "A quiet night", "Made it through"]),
        "en-GB": (["Went for a 30-minute walk this morning", "Finished the first draft of the report",
                   "Watched videos for two hours", "Didn't read a single page", "Had a long chat with a mate",
                   "Put off the gym again", "Cooked my own tea", "Scrolled shopping apps for no reason",
                   "Left work early and went for a walk", "Planned out the new project"],
                  ["That's enough for today", "A little earlier tomorrow", "I did enough", "", "A cosy evening",
                   "", "Open a book next time", "A quiet night", "Got through it"]),
        "ja": (["朝に30分歩いた", "報告書の下書きを仕上げた", "動画を2時間見てしまった", "本を1ページも読めなかった",
                "友だちと長電話した", "またジムをさぼった", "夕飯を自分で作った", "なんとなく通販アプリを眺めていた",
                "早めに退勤して散歩した", "新しい企画を整理した"],
               ["今日はここまで", "明日はもう少し早く", "よくがんばった", "", "あたたかい夜だった",
                "", "次は本を開こう", "静かな夜", "なんとか乗りきった"]),
        "ko": (["아침에 30분 걸었다", "보고서 초안을 끝냈다", "유튜브를 두 시간 봤다", "책 한 장도 못 읽었다",
                "친구와 오래 통화했다", "운동을 또 미뤘다", "저녁을 직접 해 먹었다", "괜히 쇼핑앱을 뒤적였다",
                "일찍 퇴근해서 산책했다", "새 프로젝트 기획을 정리했다"],
               ["오늘은 여기까지", "내일은 조금 더 일찍", "충분히 애썼다", "", "따뜻한 저녁이었다",
                "", "다음엔 책을 펴자", "고요한 밤", "잘 버텼다"]),
        "es": (["Caminé 30 minutos por la mañana", "Terminé el primer borrador del informe",
                "Vi vídeos durante dos horas", "No leí ni una página", "Hablé un buen rato con una amiga",
                "Volví a saltarme el gimnasio", "Me hice la cena", "Miré tiendas en el móvil sin motivo",
                "Salí pronto del trabajo y di un paseo", "Organicé el nuevo proyecto"],
               ["Hasta aquí por hoy", "Mañana, un poco antes", "Ya hice bastante", "", "Una tarde agradable",
                "", "La próxima vez, un libro", "Una noche tranquila", "Lo superé"]),
        "de": (["Morgens 30 Minuten spazieren gegangen", "Den ersten Entwurf des Berichts fertig",
                "Zwei Stunden Videos geschaut", "Keine einzige Seite gelesen", "Lange mit einer Freundin telefoniert",
                "Das Training schon wieder verschoben", "Selbst zu Abend gekocht", "Grundlos durch Shopping-Apps gescrollt",
                "Früh Feierabend gemacht und spazieren gegangen", "Das neue Projekt geplant"],
               ["Für heute reicht es", "Morgen etwas früher", "Ich habe genug getan", "", "Ein warmer Abend",
                "", "Nächstes Mal ein Buch", "Eine stille Nacht", "Durchgehalten"]),
        "zh-Hans": (["早上走了30分钟", "写完了报告初稿", "看了两个小时视频", "一页书也没读",
                     "和朋友聊了很久电话", "又把健身推迟了", "自己做了晚饭", "没事刷了半天购物软件",
                     "早点下班去散了步", "理清了新项目的思路"],
                    ["今天就到这里", "明天早一点", "已经够努力了", "", "温暖的傍晚",
                     "", "下次翻开一本书", "安静的夜晚", "总算撑过来了"]),
        "zh-Hant": (["早上走了30分鐘", "寫完了報告初稿", "看了兩個小時影片", "一頁書也沒讀",
                     "和朋友講了很久的電話", "又把運動延後了", "自己煮了晚餐", "沒事滑了半天購物 App",
                     "提早下班去散步", "整理好新企劃的方向"],
                    ["今天就到這裡", "明天早一點", "已經夠努力了", "", "溫暖的傍晚",
                     "", "下次翻開一本書", "安靜的夜晚", "總算撐過來了"]),
        "ru": (["Утром гулял 30 минут", "Закончил черновик отчёта", "Два часа смотрел видео",
                "Не прочитал ни страницы", "Долго говорил с другом по телефону", "Опять отложил спортзал",
                "Сам приготовил ужин", "Без дела листал магазины в телефоне", "Ушёл с работы пораньше и прогулялся",
                "Продумал новый проект"],
               ["На сегодня хватит", "Завтра чуть раньше", "Я сделал достаточно", "", "Тёплый вечер",
                "", "В следующий раз — книга", "Тихая ночь", "Справился"]),
        "fr": (["Marché 30 minutes ce matin", "Terminé le premier jet du rapport", "Regardé des vidéos pendant deux heures",
                "Pas lu une seule page", "Longue discussion au téléphone avec une amie", "Encore repoussé le sport",
                "Préparé moi-même le dîner", "Fait défiler des sites d’achat pour rien", "Parti tôt du travail pour me promener",
                "Posé les bases du nouveau projet"],
               ["Assez pour aujourd’hui", "Demain, un peu plus tôt", "J’en ai fait assez", "", "Une douce soirée",
                "", "La prochaine fois, un livre", "Une nuit calme", "J’ai tenu bon"]),
        "it": (["Camminato 30 minuti stamattina", "Finita la prima bozza della relazione", "Guardato video per due ore",
                "Non ho letto neanche una pagina", "Lunga telefonata con un’amica", "Rimandata di nuovo la palestra",
                "Cucinato la cena da solo", "Sfogliato app di shopping senza motivo", "Uscito presto dal lavoro per una passeggiata",
                "Impostato il nuovo progetto"],
               ["Per oggi basta così", "Domani un po’ prima", "Ho fatto abbastanza", "", "Una serata calda",
                "", "La prossima volta un libro", "Una notte tranquilla", "Ce l’ho fatta"]),
        "pt": (["Caminhei 30 minutos de manhã", "Terminei o rascunho do relatório", "Assisti vídeos por duas horas",
                "Não li nem uma página", "Conversei muito tempo com uma amiga", "Adiei a academia de novo",
                "Fiz o jantar eu mesmo", "Fiquei olhando apps de compras à toa", "Saí cedo do trabalho e caminhei",
                "Organizei o novo projeto"],
               ["Por hoje é só", "Amanhã, um pouco mais cedo", "Já fiz o bastante", "", "Uma noite aconchegante",
                "", "Na próxima, um livro", "Uma noite tranquila", "Aguentei firme"]),
        "th": (["เดินตอนเช้า 30 นาที", "เขียนร่างรายงานเสร็จแล้ว", "ดูวิดีโอไปสองชั่วโมง", "ไม่ได้อ่านหนังสือเลยสักหน้า",
                "คุยโทรศัพท์กับเพื่อนนาน", "เลื่อนออกกำลังกายอีกแล้ว", "ทำอาหารเย็นกินเอง", "ไถแอปช้อปปิ้งไปเรื่อย",
                "เลิกงานเร็วแล้วไปเดินเล่น", "วางแผนโปรเจกต์ใหม่"],
               ["วันนี้พอแค่นี้", "พรุ่งนี้เร็วขึ้นอีกนิด", "พยายามมากพอแล้ว", "", "ค่ำคืนที่อบอุ่น",
                "", "คราวหน้าเปิดหนังสือบ้าง", "คืนที่เงียบสงบ", "ผ่านมาได้แล้ว"]),
        "vi": (["Sáng nay đi bộ 30 phút", "Xong bản nháp báo cáo", "Xem video suốt hai tiếng", "Chẳng đọc được trang sách nào",
                "Gọi điện với bạn rất lâu", "Lại hoãn tập thể dục", "Tự nấu bữa tối", "Lướt app mua sắm vô cớ",
                "Tan làm sớm rồi đi dạo", "Lên kế hoạch cho dự án mới"],
               ["Hôm nay vậy là đủ", "Mai sớm hơn một chút", "Mình đã cố gắng đủ rồi", "", "Một buổi tối ấm áp",
                "", "Lần sau mở một cuốn sách", "Một đêm yên tĩnh", "Đã vượt qua"]),
        "cs": (["Ráno jsem šel na 30 minut ven", "Dokončil jsem koncept zprávy", "Dvě hodiny jsem koukal na videa",
                "Nepřečetl jsem ani stránku", "Dlouho jsem volal s kamarádem", "Zase jsem odložil cvičení",
                "Sám jsem uvařil večeři", "Jen tak jsem projížděl e-shopy", "Odešel jsem dřív z práce na procházku",
                "Promyslel jsem nový projekt"],
               ["Pro dnešek stačí", "Zítra o něco dřív", "Udělal jsem dost", "", "Teplý večer",
                "", "Příště otevřu knihu", "Tichá noc", "Zvládl jsem to"]),
        "da": (["Gik en tur på 30 minutter i morges", "Gjorde første udkast til rapporten færdigt", "Så videoer i to timer",
                "Læste ikke en eneste side", "Snakkede længe i telefon med en ven", "Udsatte træningen igen",
                "Lavede selv aftensmad", "Scrollede i shoppingapps uden grund", "Gik tidligt fra arbejde og gik en tur",
                "Planlagde det nye projekt"],
               ["Det er nok for i dag", "Lidt tidligere i morgen", "Jeg gjorde nok", "", "En varm aften",
                "", "Næste gang en bog", "En stille nat", "Kom igennem det"]),
        "el": (["Περπάτησα 30 λεπτά το πρωί", "Τελείωσα το πρώτο προσχέδιο της αναφοράς", "Είδα βίντεο για δύο ώρες",
                "Δεν διάβασα ούτε μία σελίδα", "Μίλησα πολλή ώρα στο τηλέφωνο με μια φίλη", "Ανέβαλα ξανά το γυμναστήριο",
                "Μαγείρεψα μόνος μου βραδινό", "Χάζευα εφαρμογές αγορών χωρίς λόγο", "Έφυγα νωρίς από τη δουλειά για βόλτα",
                "Οργάνωσα το νέο έργο"],
               ["Φτάνει για σήμερα", "Αύριο λίγο νωρίτερα", "Έκανα αρκετά", "", "Ένα ζεστό βράδυ",
                "", "Την επόμενη φορά ένα βιβλίο", "Μια ήσυχη νύχτα", "Τα κατάφερα"]),
        "fi": (["Kävelin aamulla 30 minuuttia", "Sain raportin luonnoksen valmiiksi", "Katsoin videoita kaksi tuntia",
                "En lukenut sivuakaan", "Puhuin pitkään puhelimessa ystävän kanssa", "Lykkäsin taas salia",
                "Tein itse illallisen", "Selasin kauppasovelluksia turhaan", "Lähdin töistä aikaisin kävelylle",
                "Suunnittelin uuden projektin"],
               ["Tämä riittää tältä päivältä", "Huomenna vähän aiemmin", "Tein tarpeeksi", "", "Lämmin ilta",
                "", "Ensi kerralla kirja", "Hiljainen yö", "Selvisin"]),
        "id": (["Jalan kaki 30 menit tadi pagi", "Draf pertama laporan selesai", "Nonton video dua jam",
                "Tidak membaca satu halaman pun", "Lama teleponan dengan teman", "Menunda olahraga lagi",
                "Masak makan malam sendiri", "Iseng scroll aplikasi belanja", "Pulang kerja lebih awal lalu jalan-jalan",
                "Menyusun rencana proyek baru"],
               ["Cukup untuk hari ini", "Besok sedikit lebih awal", "Sudah cukup berusaha", "", "Malam yang hangat",
                "", "Lain kali buka buku", "Malam yang tenang", "Berhasil melewatinya"]),
        "nb": (["Gikk en tur på 30 minutter i morges", "Ble ferdig med første utkast av rapporten", "Så på videoer i to timer",
                "Leste ikke en eneste side", "Snakket lenge i telefonen med en venn", "Utsatte treningen igjen",
                "Lagde middag selv", "Bladde i shoppingapper uten grunn", "Gikk tidlig fra jobb og tok en tur",
                "Planla det nye prosjektet"],
               ["Nok for i dag", "Litt tidligere i morgen", "Jeg gjorde nok", "", "En varm kveld",
                "", "Neste gang en bok", "En stille natt", "Kom meg gjennom det"]),
        "nl": (["Vanochtend 30 minuten gewandeld", "Eerste versie van het rapport af", "Twee uur video’s gekeken",
                "Geen enkele bladzijde gelezen", "Lang gebeld met een vriendin", "Het sporten weer uitgesteld",
                "Zelf gekookt", "Zomaar door winkelapps gescrold", "Vroeg van het werk en een wandeling gemaakt",
                "Het nieuwe project uitgestippeld"],
               ["Genoeg voor vandaag", "Morgen iets eerder", "Ik heb genoeg gedaan", "", "Een warme avond",
                "", "Volgende keer een boek", "Een stille nacht", "Ik heb het gered"]),
        "pl": (["Rano spacerowałem 30 minut", "Skończyłem pierwszą wersję raportu", "Oglądałem filmy przez dwie godziny",
                "Nie przeczytałem ani strony", "Długo rozmawiałem z przyjacielem", "Znowu odłożyłem siłownię",
                "Sam ugotowałem kolację", "Bez powodu przeglądałem sklepy w telefonie", "Wyszedłem wcześniej z pracy na spacer",
                "Rozplanowałem nowy projekt"],
               ["Na dziś wystarczy", "Jutro trochę wcześniej", "Zrobiłem dość", "", "Ciepły wieczór",
                "", "Następnym razem książka", "Cicha noc", "Dałem radę"]),
        "sv": (["Promenerade 30 minuter i morse", "Blev klar med första utkastet till rapporten", "Tittade på videor i två timmar",
                "Läste inte en enda sida", "Pratade länge i telefon med en vän", "Sköt upp träningen igen",
                "Lagade middag själv", "Scrollade i shoppingappar utan anledning", "Gick tidigt från jobbet och tog en promenad",
                "Planerade det nya projektet"],
               ["Det räcker för i dag", "Lite tidigare i morgon", "Jag gjorde tillräckligt", "", "En varm kväll",
                "", "Nästa gång en bok", "En stilla natt", "Tog mig igenom det"]),
        "tr": (["Sabah 30 dakika yürüdüm", "Raporun ilk taslağını bitirdim", "İki saat video izledim",
                "Tek sayfa bile okumadım", "Bir arkadaşımla uzun uzun konuştum", "Spor salonunu yine erteledim",
                "Akşam yemeğini kendim yaptım", "Boş yere alışveriş uygulamalarında gezindim", "İşten erken çıkıp yürüyüş yaptım",
                "Yeni projeyi planladım"],
               ["Bugünlük bu kadar", "Yarın biraz daha erken", "Yeterince çabaladım", "", "Sıcak bir akşam",
                "", "Bir dahaki sefere kitap", "Sakin bir gece", "Atlattım"]),
    ]

    private static var language: String {
        let first = Locale.preferredLanguages.first ?? "ko"
        if first.hasPrefix("en-GB") { return "en-GB" }
        if first.hasPrefix("zh-Hant") || first.hasPrefix("zh-TW") || first.hasPrefix("zh-HK") { return "zh-Hant" }
        if first.hasPrefix("zh") { return "zh-Hans" }
        let code = String(first.prefix { $0 != "-" && $0 != "_" })
        if code == "no" || code == "nn" { return "nb" }
        return demoTexts[code] != nil ? code : "en"
    }
    static var screen: String? { UserDefaults.standard.string(forKey: "debugScreen") }

    @MainActor
    static func seedIfNeeded(reflections: ReflectionManager, fragments: FragmentManager) {
        guard seedDemo, !AppLaunch.isSafeMode,
              reflections.reflections.isEmpty, fragments.fragments.isEmpty else { return }
        var rng = SeededRNG(seed: 20261013)
        let cal = Calendar.current
        let texts = demoTexts[language]!.texts
        let cats: [ReflectionCategory] = [.forged, .forged, .forged, .missed, .missed, .accept, .stop, .scattered]
        for _ in 0..<160 {
            let daysAgo = Int.random(in: 0..<360, using: &rng)
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }
            reflections.add(text: texts.randomElement(using: &rng)!,
                            category: cats.randomElement(using: &rng)!,
                            date: date)
        }
        let phrases = demoTexts[language]!.phrases
        for (i, phrase) in phrases.enumerated() {
            guard let bed = cal.date(byAdding: .day, value: -(i * 3 + 1), to: Date()) else { continue }
            fragments.add(ParchmentFragment(bedtimeDate: bed, extinguishedAt: bed.addingTimeInterval(-1200),
                                            burnProgress: Double.random(in: 0.955...0.98, using: &rng),
                                            remainingSeconds: Double.random(in: 300...1700, using: &rng),
                                            edgePhase: Double.random(in: 0...100, using: &rng),
                                            phrase: phrase))
        }
    }
}

/// 실행 인자에 따라 예시 데이터를 채우고 화면을 띄운다. 환경 객체 주입보다 **안쪽**에 걸어야 한다.
struct DebugLaunchModifier: ViewModifier {
    @EnvironmentObject var reflectionManager: ReflectionManager
    @EnvironmentObject var fragmentManager: FragmentManager
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var bedtimeManager: BedtimeManager
    @EnvironmentObject var nightManager: NightManager
    @EnvironmentObject var freeTimeManager: FreeTimeManager
    @State private var screen: String?

    func body(content: Content) -> some View {
        content
            .onAppear {
                DebugLaunch.seedIfNeeded(reflections: reflectionManager, fragments: fragmentManager)
                if UserDefaults.standard.bool(forKey: "freeTimeDemo") {
                    if !freeTimeManager.isConfigured {
                        freeTimeManager.add(weekdays: [1, 2, 3, 4, 5], startMinute: 20 * 60, endMinute: 22 * 60 + 30)
                        freeTimeManager.add(weekdays: [6, 7], startMinute: 14 * 60, endMinute: 18 * 60)
                        freeTimeManager.add(weekdays: [3], startMinute: 7 * 60, endMinute: 8 * 60)
                    }
                    bedtimeManager.selectedPeriod = .freeTime
                }
                // -period week|month|year : 그 기간 페이지로 연다 (스크린샷용)
                switch UserDefaults.standard.string(forKey: "period") {
                case "week":  bedtimeManager.selectedPeriod = .week
                case "month": bedtimeManager.selectedPeriod = .month
                case "year":  bedtimeManager.selectedPeriod = .year
                default:      break
                }
                screen = DebugLaunch.screen
            }
            .sheet(isPresented: Binding(get: { screen != nil }, set: { if !$0 { screen = nil } })) {
                destination
                    .environmentObject(reflectionManager)
                    .environmentObject(fragmentManager)
                    .environmentObject(storeManager)
                    .environmentObject(bedtimeManager)
                    .environmentObject(nightManager)
                    .environmentObject(freeTimeManager)
            }
    }

    @ViewBuilder
    private var destination: some View {
        switch screen {
        case "paywall":    PaywallView()
        case "settings":   SettingsView()
        case "fragments":  FragmentCollectionView()
        case "poster":     FragmentShareSheet(content: .poster(fragmentManager.fragments))
        case "card":
            if let f = fragmentManager.fragments.first(where: \.isBackWritten) {
                FragmentShareSheet(content: .card(f))
            }
        case "book":       NavigationStack { ReflectionBookView() }
        case "bookExport": BookExportSheet()
        case "insights":   NavigationStack { AshInsightsView() }
        case "year":
            NavigationStack {
                ScrollView { AshYearView().padding(16) }
                    .background(Color.appBackgroundWarm.ignoresSafeArea())
                    .navigationTitle("재의 흐름")
                    .navigationBarTitleDisplayMode(.inline)
            }
        case "urn":
            NavigationStack {
                ReflectionUrnView()
                    .environmentObject(reflectionManager)
                    .environmentObject(storeManager)
            }
        case "blowout":    BlowOutView()
        case "freeTime":   FreeTimeEditorView()
        case "flames":     DebugFlamePicker()
        default:           EmptyView()
        }
    }
}

/// 설정 ▸ 불꽃 종류 캐러셀만 띄운다 (설정 화면 아래쪽이라 스크린샷으로 닿기 어렵다)
private struct DebugFlamePicker: View {
    @Environment(\.flameKind) private var kind
    @Environment(\.parchmentStyle) private var style
    @AppStorage(FlameKind.storageKey) private var raw = FlameKind.classic.rawValue

    var body: some View {
        FlameKindPicker(current: kind, style: style, isPro: true) { raw = $0.rawValue }
            .frame(maxHeight: .infinity)
            .background(Color.appBackgroundWarm.ignoresSafeArea())
    }
}
#endif

extension View {
    /// DEBUG 에서만 실행 인자를 읽는다. 릴리스에서는 아무것도 하지 않는다.
    @ViewBuilder
    func debugLaunch() -> some View {
        #if DEBUG
        modifier(DebugLaunchModifier())
        #else
        self
        #endif
    }
}
