// Enums stored in the database by `.name` (drift `textEnum`). Renaming or
// removing a value is a schema change.

enum TxType { income, expense }

enum PaymentMethod { cash, bkash, nagad, bank, card }

/// A savings movement: money put into savings, or taken out.
enum SavingsDirection { deposit, withdrawal }

/// A shop-credit entry: a purchase on credit, or a payment towards the balance.
enum ShopEntryType { buy, pay }

enum TaskStatus { todo, inProgress, done, onHold }

enum PriorityLevel { high, medium, low }

enum TimerState { idle, running, paused, stopped }

enum EventCategory { office, meeting, personal, family, important, other }

/// Events use once…monthly. Reminders can also repeat on chosen weekdays (`custom`).
enum RepeatRule { once, daily, weekly, monthly, custom }

enum ReminderCategory { personal, office, bill, health, other }

enum NoteCategory { personal, office, ideas, important, other }

enum MealType { breakfast, lunch, snack, dinner }

enum GoalCategory { financial, career, learning, health, personal }

enum DocCategory { personal, office, edu, fin, other }

enum DocKind { pdf, img }
