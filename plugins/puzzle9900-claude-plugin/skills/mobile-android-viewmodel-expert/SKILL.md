---
name: mobile-android-viewmodel-expert
description: Reviews and enforces Android ViewModel best practices — single UI state, sealed class states, no UI context, proper coroutine usage, and clean data layer interaction
type: generic
disable-model-invocation: false
---

# mobile-android-viewmodel-expert

## Context

Use this skill when writing, reviewing, or refactoring Android ViewModels. It encodes Google's official ViewModel architecture guidelines and enforces patterns that keep ViewModels testable, lifecycle-safe, and free of UI references.

This skill applies to both Jetpack Compose and View-based UIs.

## What a ViewModel IS

A ViewModel is a **screen-level business logic and state holder**. It:

- Exposes a single immutable UI state to the screen
- Survives configuration changes (rotation, locale, theme)
- Is scoped to a `ViewModelStoreOwner` (Activity, Fragment, or Navigation graph destination)
- Is destroyed only when its owner is **permanently** gone

A ViewModel is **not** a general-purpose data container, a replacement for `onSaveInstanceState`, or a state holder for reusable UI components.

## Core Rules

### 1. Never hold UI context

ViewModels must **never** reference `Activity`, `Fragment`, `Context`, `View`, `Resources`, or any lifecycle-bound UI object.

```kotlin
// ❌ WRONG — memory leak, lifecycle mismatch
class MyViewModel(private val context: Context) : ViewModel()

// ✓ CORRECT — only data-layer dependencies
@HiltViewModel
class MyViewModel @Inject constructor(
    private val repository: ItemRepository,
    private val formatDateUseCase: FormatDateUseCase
) : ViewModel()
```

**Why:** The ViewModel outlives configuration changes. A destroyed Activity reference causes leaks and crashes. If you need a long-lived application context, inject it via DI — never pass it through a constructor parameter tied to a UI component.

**Do not use `AndroidViewModel`.** It couples the ViewModel to the Android framework and makes unit testing harder.

### 2. Single UI state with a single StateFlow

Expose **one** `StateFlow<UiState>` per screen. The backing `MutableStateFlow` stays private.

```kotlin
data class ProfileUiState(
    val isLoading: Boolean = false,
    val user: User? = null,
    val error: String? = null
)

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val userRepository: UserRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    fun loadProfile(userId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val user = userRepository.getUser(userId)
                _uiState.update { it.copy(isLoading = false, user = user) }
            } catch (e: IOException) {
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }
}
```

**Key points:**

- Use `.update {}` for atomic state mutations — never read `.value` and then assign
- Use `.asStateFlow()` to expose an immutable view
- Always provide an initial state value
- Prefer a single combined state over many independent flows — it prevents inconsistent UI snapshots

### 3. Represent states with sealed classes

Use sealed classes (or sealed interfaces) when the screen has **mutually exclusive** states:

```kotlin
sealed interface FeedUiState {
    data object Loading : FeedUiState
    data class Success(val articles: List<Article>) : FeedUiState
    data class Error(val message: String) : FeedUiState
}

@HiltViewModel
class FeedViewModel @Inject constructor(
    private val newsRepository: NewsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow<FeedUiState>(FeedUiState.Loading)
    val uiState: StateFlow<FeedUiState> = _uiState.asStateFlow()

    fun refresh() {
        viewModelScope.launch {
            _uiState.value = FeedUiState.Loading
            try {
                val articles = newsRepository.getArticles()
                _uiState.value = FeedUiState.Success(articles)
            } catch (e: Exception) {
                _uiState.value = FeedUiState.Error(e.message ?: "Unknown error")
            }
        }
    }
}
```

**When to use sealed class vs data class:**

| Pattern | When to use |
|---|---|
| Sealed class/interface | States are mutually exclusive (Loading, Success, Error) |
| Data class with fields | States can overlap (loading + partial data + optional error) |

### 4. Data layer interaction: repositories, use cases, managers

ViewModels delegate all data access to the **data layer**. They never call APIs, databases, or shared preferences directly.

```
UI → ViewModel → Use Case (optional) → Repository → Data Source
```

```kotlin
@HiltViewModel
class SearchViewModel @Inject constructor(
    private val searchRepository: SearchRepository,
    private val formatResultsUseCase: FormatResultsUseCase
) : ViewModel() {

    private val query = MutableStateFlow("")

    val results: StateFlow<SearchUiState> = query
        .debounce(300)
        .flatMapLatest { q ->
            if (q.isBlank()) flowOf(SearchUiState.Empty)
            else searchRepository.search(q)
                .map { items -> SearchUiState.Success(formatResultsUseCase(items)) }
                .catch { e -> emit(SearchUiState.Error(e.message ?: "Search failed")) }
        }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = SearchUiState.Empty
        )

    fun setQuery(newQuery: String) {
        query.value = newQuery
    }
}
```

**Dependency injection rules:**

- Inject **interfaces**, not concrete classes
- Repositories handle data source coordination
- Use cases encapsulate reusable business logic (optional — skip if the logic is trivial)
- Managers coordinate cross-feature concerns (e.g., session manager, sync manager)

### 5. Coroutine best practices

**Always use `viewModelScope`** — it cancels automatically when the ViewModel is cleared.

```kotlin
// ✓ CORRECT — ViewModel creates and owns coroutines
fun loadData() {
    viewModelScope.launch {
        val data = repository.getData()
        _uiState.update { it.copy(data = data) }
    }
}

// ❌ WRONG — exposing suspend functions forces UI to manage coroutines
suspend fun loadData(): Data = repository.getData()
```

**Inject dispatchers** — never hardcode `Dispatchers.IO` or `Dispatchers.Default`:

```kotlin
class MyRepository(
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO
) {
    suspend fun fetchData() = withContext(ioDispatcher) {
        api.getData()
    }
}
```

**Use `SharingStarted.WhileSubscribed(5_000)`** for reactive flows — it stops upstream collection when no UI is observing, with a 5-second grace period for configuration changes:

```kotlin
val uiState: StateFlow<State> = repository.observe()
    .stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = State.Loading
    )
```

**Never catch `CancellationException`** — let it propagate so coroutine cancellation works correctly.

### 6. One-time events: avoid events in state

Do **not** put transient events (toasts, navigation, snackbars) in the UI state data class. They get replayed on recomposition or configuration change.

```kotlin
// ❌ WRONG — toast replays on rotation
data class UiState(val showToast: String? = null)

// ✓ CORRECT — handle the result immediately, update state to reflect outcome
sealed interface DeleteUiState {
    data object Idle : DeleteUiState
    data object Deleting : DeleteUiState
    data object Deleted : DeleteUiState   // UI navigates away when it sees this
    data class Failed(val reason: String) : DeleteUiState
}
```

If you truly need a fire-and-forget event, use `SharedFlow` with `replay = 0`:

```kotlin
private val _events = MutableSharedFlow<UiEvent>()
val events: SharedFlow<UiEvent> = _events.asSharedFlow()
```

But **prefer state-based approaches** — they survive configuration changes and are easier to test.

### 7. SavedStateHandle for process death survival

Use `SavedStateHandle` to persist **business-logic state** (not UI state) across process death:

```kotlin
@HiltViewModel
class FilterViewModel @Inject constructor(
    private val savedStateHandle: SavedStateHandle,
    private val repository: ItemRepository
) : ViewModel() {

    private val selectedCategory: StateFlow<String?> =
        savedStateHandle.getStateFlow("category", null)

    val items: StateFlow<ItemsUiState> = selectedCategory
        .flatMapLatest { cat -> repository.getItems(cat) }
        .map { ItemsUiState.Success(it) }
        .catch { emit(ItemsUiState.Error(it.message ?: "Failed")) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ItemsUiState.Loading)

    fun selectCategory(category: String) {
        savedStateHandle["category"] = category
    }
}
```

**Save:** search queries, filter selections, selected IDs, scroll anchor IDs.
**Do not save:** full API responses, large lists, complex objects — use local persistence (Room, DataStore) instead.

### 8. Lifecycle-aware collection in UI

**Views (Activity/Fragment):**

```kotlin
viewLifecycleOwner.lifecycleScope.launch {
    viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
        viewModel.uiState.collect { state -> updateUI(state) }
    }
}
```

**Compose:**

```kotlin
val uiState by viewModel.uiState.collectAsStateWithLifecycle()
```

Never use `.collect {}` without lifecycle awareness — it keeps collecting when the UI is in the background, wasting resources and potentially updating destroyed views.

### 9. Testing ViewModels

ViewModels are plain Kotlin classes with injected dependencies — unit test them without Android framework dependencies:

```kotlin
class FeedViewModelTest {
    private val fakeRepository = FakeNewsRepository()
    private lateinit var viewModel: FeedViewModel

    @Before
    fun setup() {
        viewModel = FeedViewModel(fakeRepository)
    }

    @Test
    fun `initial state is Loading`() {
        assertEquals(FeedUiState.Loading, viewModel.uiState.value)
    }

    @Test
    fun `refresh emits Success with articles`() = runTest {
        fakeRepository.setArticles(listOf(Article("1", "Title")))

        viewModel.refresh()
        advanceUntilIdle()

        val state = viewModel.uiState.value
        assertIs<FeedUiState.Success>(state)
        assertEquals(1, state.articles.size)
    }

    @Test
    fun `refresh emits Error on failure`() = runTest {
        fakeRepository.setError(IOException("Network"))

        viewModel.refresh()
        advanceUntilIdle()

        assertIs<FeedUiState.Error>(viewModel.uiState.value)
    }
}
```

**Testing checklist:**

- Replace real dependencies with fakes (not mocks — fakes are simpler and more reliable)
- Use `runTest` + `advanceUntilIdle()` for coroutine testing
- Inject `StandardTestDispatcher` or `UnconfinedTestDispatcher` via DI
- Assert on `StateFlow.value` (StateFlow conflates, so intermediate emissions may be dropped)
- Test initial state, success path, error path, and edge cases

## Anti-Patterns Summary

| Anti-Pattern | Why it's wrong | Correct approach |
|---|---|---|
| Holding `Context`/`Activity`/`View` | Memory leaks, crashes after config change | Inject data-layer dependencies only |
| Using `AndroidViewModel` | Framework coupling, harder to test | Use `ViewModel` with DI |
| Multiple exposed flows per screen | Inconsistent UI snapshots | Single `StateFlow<UiState>` |
| Events in state (`showToast: Boolean`) | Replays on recomposition/rotation | Sealed state or `SharedFlow` |
| Exposing `suspend fun` from ViewModel | UI must manage coroutines | Launch in `viewModelScope`, expose `StateFlow` |
| Hardcoded `Dispatchers.IO` | Untestable | Inject `CoroutineDispatcher` |
| Direct API/DB calls in ViewModel | Violates separation of concerns | Delegate to repository/use case |
| `GlobalScope` or custom `CoroutineScope` | No automatic cancellation | Use `viewModelScope` |
| Collecting without lifecycle awareness | Background updates, wasted resources | `repeatOnLifecycle` or `collectAsStateWithLifecycle` |
| Catching `CancellationException` | Breaks coroutine cancellation | Let it propagate |
| Mutable state exposure | UI can accidentally mutate state | `.asStateFlow()` for read-only access |
| Launching eagerly in `init` | Wasted resources if state isn't observed | Use `SharingStarted.WhileSubscribed` or explicit triggers |

## Constraints

- All examples use Kotlin — Java ViewModels should follow the same structural patterns using `LiveData` equivalents
- This skill is a reference — it does not modify code unless combined with a review or refactoring task
- All patterns assume Hilt for dependency injection; adapt `@HiltViewModel` / `@Inject` annotations to your DI framework
- Do not treat these rules as absolute — document deviations with a comment explaining the reason
