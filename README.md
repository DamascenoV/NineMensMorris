# Nine Men's Morris

A web-based implementation of the classic Nine Men's Morris board game, built with Elixir and Phoenix Framework. This project serves as a learning exercise to explore Elixir's functional programming paradigm and Phoenix's real-time capabilities.

## About This Project

This project was inspired by the board game featured in the Netflix series "The Devil's Plan" (더 데빌스 플랜). The goal is to deepen understanding of:

- **Elixir**: Functional programming, OTP, and concurrent processes
- **Phoenix Framework**: Real-time web applications, LiveView, and WebSockets
- **Game Logic**: Implementing turn-based strategy games with state management

## Features

### **Core Gameplay**
- **Real-time Gameplay**: Live multiplayer matches using Phoenix LiveView
- **Game Lobby**: Join or create games with other players
- **Interactive Board**: Click-to-move interface with visual feedback
- **Game State Management**: Persistent game state with Elixir's GenServer
- **Private Games**: Password-protected games for exclusive matches
- **Player Sessions**: Persistent player sessions with secure ID generation

### **User Experience**
- **Responsive Design**: Mobile-friendly interface built with Tailwind CSS
- **Real-time Updates**: Live game state synchronization across players
- **Visual Feedback**: Clear indicators for game actions and errors
- **Intuitive Interface**: Easy-to-use controls and game flow

##  Getting Started

### Prerequisites

- Elixir 1.14 or later
- Erlang 25 or later

### Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd nine_mens_morris
   ```

2. **Install dependencies**
   ```bash
   mix deps.get
   ```

3. **Start the Phoenix server**
   ```bash
   mix phx.server
   ```

4. **Visit the application**
   Open [`http://localhost:4000`](http://localhost:4000) in your browser

## How to Play

Nine Men's Morris is a strategy board game for two players. The objective is to reduce your opponent to two pieces or block all their possible moves.

### Game Rules

1. **Placing Phase**: Each player places 9 pieces on the board
2. **Moving Phase**: Players move pieces to adjacent positions
3. **Flying Phase**: When reduced to 3 pieces, players can "fly" to any empty position
4. **Mills**: Three pieces in a row form a "mill" - remove opponent's piece
5. **Winning**: Reduce opponent to 2 pieces or block all their moves

### Game Features

- **Real-time Multiplayer**: Play with friends in real-time
- **Private Games**: Create password-protected games
- **Session Persistence**: Rejoin games after disconnection
- **Visual Feedback**: Clear indicators for valid moves and errors
- **Responsive Design**: Play on desktop or mobile devices

## 📁 Project Structure

```
lib/
├── nine_mens_morris/
│   ├── game/
│   │   ├── actions.ex      # Game action handlers with error management
│   │   ├── errors.ex       # Standardized error handling
│   │   ├── logic.ex        # Core game rules and logic
│   │   ├── state.ex        # Game state management with validation
│   │   └── gen_server.ex   # Game process management (optimized)
│   ├── board.ex            # Board representation and validation
│   ├── board_coordinates.ex # Coordinate system and utilities
│   ├── game_registry.ex    # Game process registry
│   └── game_supervisor.ex  # Game process supervision
└── nine_mens_morris_web/
    ├── live/
    │   ├── game_live.ex           # Main game LiveView (refactored)
    │   ├── game_live_helpers.ex   # Game LiveView utilities
    │   ├── lobby_live.ex          # Game lobby
    │   └── game_live.html.heex    # Game templates
    ├── components/         # Reusable UI components
    └── controllers/        # Web controllers

test/
├── nine_mens_morris/
│   ├── game/               # Game logic tests (enhanced)
│   │   ├── actions_test.exs
│   │   ├── errors_test.exs
│   │   ├── logic_test.exs
│   │   └── state_test.exs
│   ├── board_test.exs
│   ├── board_coordinates_test.exs
│   └── game_registry_test.exs
└── nine_mens_morris_web/
    ├── live/               # LiveView tests (enhanced)
    │   ├── game_live_test.exs
    │   ├── game_live_helpers_test.exs
    │   └── lobby_live_test.exs
    └── controllers/
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Inspired by**: "The Devil's Plan" Netflix series
- **Built with**: The amazing [Phoenix Framework](https://www.phoenixframework.org/)
- **Elixir Community**: Thanks for excellent documentation and support
- **Open Source Tools**: Credo, Dialyzer, and the entire Elixir ecosystem
- **Learning Journey**: This project represents a deep dive into functional programming and real-time web applications

### 📚 Additional Resources

- [Phoenix Framework Guides](https://hexdocs.pm/phoenix/overview.html)
- [Elixir Documentation](https://elixir-lang.org/docs.html)
- [Nine Men's Morris Rules](https://en.wikipedia.org/wiki/Nine_men%27s_morris)
- [Phoenix LiveView Documentation](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
