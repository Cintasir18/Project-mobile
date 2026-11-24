import 'dart:math';

import 'package:flutter/material.dart';

import 'package:elora_school/theme/colors.dart';
import 'package:elora_school/widgets/elora_components.dart';

enum GameMode { computer, twoPlayers }

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  // ============================================================
  // GAME STATE
  // ============================================================

  GameMode gameMode = GameMode.computer;

  List<String> board = List.filled(9, '');

  String currentPlayer = 'X';

  String? winner;

  List<int> winningLine = [];

  bool isGameOver = false;
  bool isComputerThinking = false;

  int scoreX = 0;
  int scoreO = 0;
  int drawCount = 0;

  int roundCount = 1;

  final Random _random = Random();

  static const Color playerXColor = Color(0xFF046C69);
  static const Color playerOColor = Color(0xFFFFA94D);
  static const Color drawColor = Color(0xFF8A8F98);

  // ============================================================
  // GAME LOGIC
  // ============================================================

  static const List<List<int>> winningCombinations = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  Color get currentPlayerColor {
    return currentPlayer == 'X' ? playerXColor : playerOColor;
  }

  String get currentPlayerName {
    if (gameMode == GameMode.computer) {
      return currentPlayer == 'X' ? 'You' : 'ELORA AI';
    }

    return currentPlayer == 'X' ? 'Player 1' : 'Player 2';
  }

  String get winnerName {
    if (winner == null) return 'Permainan Seri';

    if (gameMode == GameMode.computer) {
      return winner == 'X' ? 'Kamu Menang!' : 'ELORA AI Menang!';
    }

    return winner == 'X' ? 'Pemain 1 Menang!' : 'Pemain 2 Menang!';
  }

  Color get winnerColor {
    if (winner == null) return drawColor;

    return winner == 'X' ? playerXColor : playerOColor;
  }

  // ============================================================
  // HANDLE CELL TAP
  // ============================================================

  void _handleCellTap(int index) {
    if (isGameOver || isComputerThinking || board[index].isNotEmpty) {
      return;
    }

    _makeMove(index);

    if (isGameOver) return;

    if (gameMode == GameMode.computer && currentPlayer == 'O') {
      _playComputer();
    }
  }

  void _makeMove(int index) {
    if (board[index].isNotEmpty || isGameOver) return;

    setState(() {
      board[index] = currentPlayer;
    });

    _checkGameResult();

    if (!isGameOver) {
      setState(() {
        currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
      });
    }
  }

  // ============================================================
  // CHECK WINNER
  // ============================================================

  void _checkGameResult() {
    for (final combination in winningCombinations) {
      final a = combination[0];
      final b = combination[1];
      final c = combination[2];

      if (board[a].isNotEmpty && board[a] == board[b] && board[b] == board[c]) {
        _finishGame(board[a], combination);
        return;
      }
    }

    if (!board.contains('')) {
      _finishGame(null, []);
    }
  }

  void _finishGame(String? result, List<int> line) {
    setState(() {
      isGameOver = true;
      winner = result;
      winningLine = line;

      if (result == 'X') {
        scoreX++;
      } else if (result == 'O') {
        scoreO++;
      } else {
        drawCount++;
      }
    });
  }

  // ============================================================
  // COMPUTER MOVE
  // ============================================================

  Future<void> _playComputer() async {
    if (isGameOver) return;

    setState(() {
      isComputerThinking = true;
    });

    // Jeda singkat agar langkah komputer terasa natural.
    await Future.delayed(const Duration(milliseconds: 550));

    if (!mounted || isGameOver) return;

    final move = _getComputerMove();

    setState(() {
      isComputerThinking = false;
    });

    if (move != -1) {
      _makeMove(move);
    }
  }

  int _getComputerMove() {
    final available = <int>[];

    for (int i = 0; i < board.length; i++) {
      if (board[i].isEmpty) {
        available.add(i);
      }
    }

    if (available.isEmpty) return -1;

    // 1. Prioritaskan langkah untuk menang.
    final winningMove = _findWinningMove('O');

    if (winningMove != -1) {
      return winningMove;
    }

    // 2. Blokir kemenangan pemain.
    final blockingMove = _findWinningMove('X');

    if (blockingMove != -1) {
      return blockingMove;
    }

    // 3. Ambil tengah jika tersedia.
    if (board[4].isEmpty) {
      return 4;
    }

    // 4. Ambil salah satu sudut.
    final corners = [
      0,
      2,
      6,
      8,
    ].where((index) => board[index].isEmpty).toList();

    if (corners.isNotEmpty) {
      return corners[_random.nextInt(corners.length)];
    }

    // 5. Pilih kotak kosong lainnya.
    return available[_random.nextInt(available.length)];
  }

  int _findWinningMove(String player) {
    for (final combination in winningCombinations) {
      final cells = combination.map((index) => board[index]).toList();

      final playerCount = cells.where((v) => v == player).length;
      final emptyCount = cells.where((v) => v.isEmpty).length;

      if (playerCount == 2 && emptyCount == 1) {
        return combination.firstWhere((index) => board[index].isEmpty);
      }
    }

    return -1;
  }

  // ============================================================
  // RESET GAME
  // ============================================================

  void _resetRound() {
    setState(() {
      board = List.filled(9, '');

      currentPlayer = 'X';
      winner = null;
      winningLine = [];

      isGameOver = false;
      isComputerThinking = false;

      roundCount++;
    });
  }

  void _resetScore() {
    setState(() {
      scoreX = 0;
      scoreO = 0;
      drawCount = 0;
      roundCount = 1;

      board = List.filled(9, '');
      currentPlayer = 'X';

      winner = null;
      winningLine = [];

      isGameOver = false;
      isComputerThinking = false;
    });
  }

  void _changeMode(GameMode mode) {
    if (gameMode == mode) return;

    setState(() {
      gameMode = mode;

      board = List.filled(9, '');
      currentPlayer = 'X';

      winner = null;
      winningLine = [];

      scoreX = 0;
      scoreO = 0;
      drawCount = 0;

      roundCount = 1;

      isGameOver = false;
      isComputerThinking = false;
    });
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eloraBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 22),

              _buildHeroCard(),

              const SizedBox(height: 22),

              _buildModeSelector(),

              const SizedBox(height: 22),

              _buildScoreBoard(),

              const SizedBox(height: 24),

              _buildGameStatus(),

              const SizedBox(height: 16),

              _buildGameBoard(),

              const SizedBox(height: 20),

              _buildGameActions(),

              const SizedBox(height: 20),

              _buildHowToPlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: eloraDark,
        ),

        const Expanded(
          child: Text(
            'Mini Games',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: eloraDark,
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: eloraPrimary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.sports_esports_rounded,
            color: eloraPrimary,
            size: 23,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HERO CARD
  // ============================================================

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF046C69), Color(0xFF078D83), Color(0xFF27A99A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -15,
            child: Icon(
              Icons.grid_3x3_rounded,
              size: 115,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ELORA MINI GAME',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Tic Tac Toe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'Asah strategi, tentukan langkahmu, '
                ' dan jadilah yang pertama menyusun tiga simbol sejajar!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EloraSectionHeader(title: 'Mode Game'),

        const SizedBox(height: 13),

        Row(
          children: [
            Expanded(
              child: _modeCard(
                title: 'VS Computer',
                subtitle: 'Play with ELORA AI',
                icon: Icons.smart_toy_rounded,
                mode: GameMode.computer,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: _modeCard(
                title: '2 Players',
                subtitle: 'Play with a friend',
                icon: Icons.people_alt_rounded,
                mode: GameMode.twoPlayers,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _modeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required GameMode mode,
  }) {
    final selected = gameMode == mode;

    return EloraCard(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(17),
      color: selected ? eloraPrimary.withValues(alpha: 0.07) : eloraCard,
      border: Border.all(
        color: selected ? eloraPrimary : eloraInput,
        width: selected ? 1.5 : 1,
      ),
      onTap: () => _changeMode(mode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: selected ? eloraPrimary : eloraBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: selected ? Colors.white : eloraPrimary,
              size: 21,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style: TextStyle(
              color: selected ? eloraPrimary : eloraDark,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 9),
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? eloraPrimary : Colors.grey.shade400,
                size: 15,
              ),

              const SizedBox(width: 5),

              Text(
                selected ? 'Selected' : 'Select mode',
                style: TextStyle(
                  color: selected ? eloraPrimary : Colors.grey.shade500,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SCOREBOARD
  // ============================================================

  Widget _buildScoreBoard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EloraSectionHeader(
          title: 'Match Score',
          subtitle: 'Statistik game anda.',
        ),

        const SizedBox(height: 13),

        Row(
          children: [
            Expanded(
              child: _scoreCard(
                symbol: 'X',
                label: gameMode == GameMode.computer ? 'YOU' : 'PLAYER 1',
                score: scoreX,
                color: playerXColor,
                isActive: currentPlayer == 'X' && !isGameOver,
              ),
            ),

            const SizedBox(width: 9),

            Expanded(
              child: _scoreCard(
                symbol: 'O',
                label: gameMode == GameMode.computer ? 'ELORA AI' : 'PLAYER 2',
                score: scoreO,
                color: playerOColor,
                isActive: currentPlayer == 'O' && !isGameOver,
              ),
            ),

            const SizedBox(width: 9),

            Expanded(
              child: _scoreCard(
                symbol: '=',
                label: 'DRAW',
                score: drawCount,
                color: drawColor,
                isActive: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _scoreCard({
    required String symbol,
    required String label,
    required int score,
    required Color color,
    required bool isActive,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.09) : eloraCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? color : eloraInput.withValues(alpha: 0.6),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            symbol,
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            '$score',
            style: const TextStyle(
              color: eloraDark,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GAME STATUS
  // ============================================================

  Widget _buildGameStatus() {
    final Color statusColor = isGameOver ? winnerColor : currentPlayerColor;

    String title;
    String subtitle;

    if (isGameOver) {
      title = winner == null ? 'It is a Draw!' : winnerName;
      subtitle = winner == null
          ? 'Great match! Nobody wins this round.'
          : 'Congratulations on your victory!';
    } else if (isComputerThinking) {
      title = 'ELORA AI is thinking...';
      subtitle = 'Wait a moment for the next move.';
    } else {
      title = '$currentPlayerName\'s Turn';
      subtitle = 'Pilih kotak kosong.';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: statusColor.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: isComputerThinking
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: eloraPrimary,
                      ),
                    )
                  : Text(
                      isGameOver ? (winner ?? '=') : currentPlayer,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                ),
              ],
            ),
          ),

          if (isGameOver)
            const Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFFB52E),
              size: 27,
            ),
        ],
      ),
    );
  }

  // ============================================================
  // GAME BOARD
  // ============================================================

  Widget _buildGameBoard() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: eloraInput.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: eloraDark.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
          ),
          itemBuilder: (context, index) {
            return _buildCell(index);
          },
        ),
      ),
    );
  }

  Widget _buildCell(int index) {
    final value = board[index];

    final isWinningCell = winningLine.contains(index);

    final Color symbolColor = value == 'X' ? playerXColor : playerOColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isWinningCell
            ? symbolColor.withValues(alpha: 0.14)
            : eloraBackground,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isWinningCell
              ? symbolColor
              : value.isNotEmpty
              ? symbolColor.withValues(alpha: 0.20)
              : eloraInput.withValues(alpha: 0.45),
          width: isWinningCell ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: value.isEmpty ? () => _handleCellTap(index) : null,
          child: Center(
            child: AnimatedScale(
              scale: value.isEmpty ? 0.7 : 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: value.isEmpty
                  ? Icon(
                      Icons.add_rounded,
                      color: Colors.grey.shade300,
                      size: 25,
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        color: symbolColor,
                        fontSize: 47,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GAME ACTIONS
  // ============================================================

  Widget _buildGameActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 51,
            child: FilledButton.icon(
              onPressed: _resetRound,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'New Round',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: eloraPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        SizedBox(
          height: 51,
          child: OutlinedButton(
            onPressed: _confirmResetScore,
            style: OutlinedButton.styleFrom(
              foregroundColor: eloraPrimary,
              side: const BorderSide(color: eloraPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15),
            ),
            child: const Icon(Icons.restart_alt_rounded),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmResetScore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset Score?'),
          content: const Text(
            'Semua skor pertandingan akan dihapus. '
            'Apakah kamu ingin melanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      _resetScore();
    }
  }

  // ============================================================
  // HOW TO PLAY
  // ============================================================

  Widget _buildHowToPlay() {
    return EloraCard(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: eloraPrimary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Cara Bermain',
                style: TextStyle(
                  color: eloraDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          _instructionItem(
            '1',
            'Pemain bergantian menempatkan simbol X dan O pada papan.',
          ),

          _instructionItem(
            '2',
            'Jadilah pemain pertama yang menyusun tiga simbol sejajar.',
          ),

          _instructionItem(
            '3',
            'Susunan simbol dapat dibuat secara horizontal, vertikal, atau diagonal.',
          ),

          _instructionItem(
            '4',
            'Jika seluruh kotak terisi tanpa ada pemenang, permainan berakhir seri.',
          ),
        ],
      ),
    );
  }

  Widget _instructionItem(String number, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 21,
            height: 21,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: eloraPrimary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: eloraPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
