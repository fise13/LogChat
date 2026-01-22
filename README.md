LogChat
LogChat — персональный AI‑ассистент и дневник для разработчиков и создателей контента.
Приложение объединяет чат с ИИ, историю диалогов, заметки, «память» о пользователе, проекты и фокус‑сессии, а также синхронизацию через Firebase и iCloud (CloudKit).
Основные возможности
AI‑чат
Диалоги с несколькими режимами (AIMode: coding, planner, daily и др.).
Поддержка контекста, токен‑лимитов и индикация использования токенов.
Быстрые действия (Quick Actions) и шаблоны запросов.
История чатов
Список всех чатов с поиском, фильтрацией по режиму и тегам.
Переход к любому чату и продолжение диалога.
Экспорт / копирование ответов.
Память (Memory)
Модель MemoryItem: долговременные факты о пользователе и проектах.
Автоматическое извлечение и обновление памяти из диалогов.
Отдельный экран для просмотра и редактирования памяти.
Заметки и статистика
Раздел NotesView с заметками (Note, NoteColor).
Экран StatisticsView с агрегированной статистикой использования (чаты, сообщения, токены и др.).
Проекты и агент‑аналитик
Модели Project, ProjectTask, ProjectReport.
ProjectAnalysisService и ResearchService для анализа проектов и генерации отчётов.
Интеграция с чат‑агентом для работы по проектам.
Фокус‑сессии
Экран FocusSessionView с учётом времени, задач и прогресса.
Синхронизация и облако
CloudKit (CloudKitService) — синхронизация памяти, проектов и чатов через iCloud.
Firebase (FirebaseService, SyncService) — синхронизация настроек и данных (опционально, при наличии конфигурации).
Безопасность и конфиденциальность
Биометрическая блокировка (SecurityService, LockScreenView).
Режим «Инкогнито» и анонимизация данных.
Гибкие настройки сохранения истории.
Кастомизация интерфейса
Собственный дизайн‑система DesignSystem (цвета, типографика, тени, анимации).
Настройки темы, размеров шрифта, лимитов контекста и др.
Современный UI на SwiftUI, адаптированный под iOS.
Технологии
Язык и UI
Swift, SwiftUI
SwiftData (модели @Model для Chat, Message, Note, Project, Memory и др.)
Сетевые и AI‑сервисы
AIService, LLMService и LLMProvider с провайдерами:
OpenAIProvider
AnthropicProvider
OpenRouterProvider
SearchService для веб‑поиска через внешние API.
Хранение и синхронизация
SwiftData (локальное хранилище)
CloudKit (CloudKitService)
Firebase (FirebaseService) — через GoogleService-Info.plist
Дополнительно
Уведомления (NotificationService)
Кэширование (CacheService)
История и экспорт (HistoryService, ExportService)
Анализ и извлечение памяти (MemoryExtractionService, MemoryService)
Подсказки (SmartSuggestionsService, SuggestionChatView)
Структура проекта
LogChat/LogChatApp.swift
Точка входа приложения, создание WindowGroup с RootView и конфигурация Firebase (iOS).
LogChat/Views
RootView.swift — главный контейнер навигации (TabView + LockScreen).
DashboardView.swift — дашборд, быстрые действия, статистика дня.
ChatView.swift + компоненты в Views/Components:
ChatMessagesListView.swift, MessageRowView.swift, InputBarView.swift,
ModelSelectorView.swift, TokenIndicatorView.swift, MarkdownContentView.swift и др.
Другие основные экраны:
HistoryView.swift
MemoryView.swift
NotesView.swift
StatisticsView.swift
FocusSessionView.swift
TemplatesView.swift
SettingsView.swift
LockScreenView.swift
LogChat/ViewModels
ChatViewModel.swift — логика чата, отправка сообщений, учёт токенов, режимы.
AgentViewModel.swift ранее использовался для macOS‑агента (файл удалён при переходе только на iOS).
LogChat/Models
Chat, Message, Mode (AIMode)
Note, NoteColor
Project, ProjectTask, ProjectReport
MemoryItem, ResearchState, FocusSession, UsageStatistics и др. (по фактическим моделям в папке).
LogChat/Services
AI: AIService, LLMService + LLM/Providers
Данные и синхронизация: CloudKitService, FirebaseService, SyncService, HistoryService
Память и анализ: MemoryService, MemoryExtractionService, ProjectAnalysisService, ResearchService, SummaryService
Безопасность и утилиты: SecurityService, TokenService, SearchService, NotificationService, ExportService, SmartSuggestionsService
LogChat/Design/DesignSystem.swift
Единая точка для цветов, шрифтов, отступов, анимаций и вспомогательных расширений.
LogChat/Platform/PlatformHelper.swift
Упрощённый helper для определения текущей платформы (сейчас только iOS).
LogChat/Utils
ImageProcessor.swift — сжатие изображений (iOS).
LanguageDetector.swift — определение языка текста.
Требования
Xcode: 16+ (актуальная версия под macOS 15)
iOS: 17+ / 18+ (см. deployment target в настройках таргета LogChat)
Swift: версия по умолчанию Xcode
Учётные данные:
OpenRouter / OpenAI / Anthropic API‑ключи (по выбору).
(Опционально) Firebase — корректный GoogleService-Info.plist.
(Опционально) CloudKit — включённый iCloud и настроенный контейнер iCloud.fise.LogChat.
Настройка проекта
1. Клонирование
git clone <repo-url>cd LogChat
2. Открытие в Xcode
Откройте LogChat.xcodeproj в Xcode.
3. Настройка Bundle ID и CloudKit
В Xcode откройте таргет LogChat → Signing & Capabilities.
Установите свой Bundle Identifier (например, com.yourname.LogChat).
Если хотите использовать CloudKit:
Включите iCloud → CloudKit.
Задайте контейнер iCloud.<ВашBundleId> и обновите идентификатор в CloudKitService (поле CKContainer(identifier: ...)).
4. Настройка Firebase (опционально)
Скачайте GoogleService-Info.plist из Firebase Console и поместите в корень iOS‑таргета (/LogChat/GoogleService-Info.plist).
Убедитесь, что файл добавлен в таргет LogChat.
5. API‑ключи LLM и поиска
Все ключи задаются через настройки внутри приложения (SettingsView):
OpenRouter API key: хранится в @AppStorage("openRouterAPIKey").
Search API key: задаётся через секцию Web Search и сохраняется в UserDefaults через SearchService.updateAPIKey(_:).
Дополнительные ключи провайдеров (если используются) настраиваются аналогично через AIService / LLMService.
Запуск
Выберите схему LogChat и устройство / симулятор iOS.
Нажмите Run (⌘R).
При первом запуске:
Разрешите уведомления (если появится диалог).
Включите биометрию и другие опции в Settings.
Основные сценарии использования
Быстрый старт:
Откройте приложение, на экране Dashboard выберите быстрый сценарий (например, «Объяснить код»).
Вас перекинет в чат с заранее подготовленным промптом и режимом.
Работа с историей:
Перейдите во вкладку History, найдите нужный чат по тексту / тегам / режиму.
Откройте чат и продолжите диалог.
Память:
В ходе диалога сервис MemoryExtractionService может извлекать факты о вас или ваших проектах.
Просмотреть и отредактировать память можно во вкладке Memory или из настроек (секция My Memory).
Заметки и фокус‑сессии:
Во вкладке Notes ведите заметки с цветами и тегами.
Во вкладке Focus запускайте фокус‑сессии с трекингом времени и задач.
Архитектура (кратко)
MVVM + сервисный слой
View (SwiftUI) → ViewModel (ChatViewModel, и др.) → Сервисы (AIService, HistoryService, SyncService…).
Хранение
SwiftData как основное локальное хранилище.
Сервисы синхронизации (CloudKitService, FirebaseService, SyncService) работают поверх моделей SwiftData.
Интеграция LLM
LLMService выбирает провайдера (OpenAIProvider, AnthropicProvider, OpenRouterProvider) в зависимости от настроек.
AIService инкапсулирует бизнес‑логику: режимы, лимиты токенов, типы сообщений и т.д.
Известные ограничения
Проект сейчас ориентирован только на iOS — весь macOS‑код и macOS‑UI удалены.
Некоторые фичи (Firebase, CloudKit) требуют отдельной настройки entitlements и конфигурации, без этого они будут отключены или выводить предупреждения в лог.