import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const SubwayRunnerApp());
}

class SubwayRunnerApp extends StatelessWidget {
  const SubwayRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '地铁跑酷',
      theme: ThemeData.dark(useMaterial3: true),
      home: const SubwayGamePage(),
    );
  }
}

class SubwayGamePage extends StatefulWidget {
  const SubwayGamePage({super.key});

  @override
  State<SubwayGamePage> createState() => _SubwayGamePageState();
}

class _SubwayGamePageState extends State<SubwayGamePage> {
  static const int laneCount = 3;
  static const double obstacleSpeed = 0.018;
  static const double jumpDuration = 0.6;

  final Random _random = Random();
  final List<Obstacle> _obstacles = <Obstacle>[];

  Timer? _timer;
  int _lane = 1;
  bool _isPlaying = false;
  bool _isJumping = false;
  double _jumpT = 0;
  int _score = 0;
  int _bestScore = 0;
  double _spawnCooldown = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _timer?.cancel();
    setState(() {
      _isPlaying = true;
      _lane = 1;
      _score = 0;
      _jumpT = 0;
      _spawnCooldown = 0;
      _isJumping = false;
      _obstacles.clear();
    });

    _timer = Timer.periodic(const Duration(milliseconds: 16), (Timer timer) {
      const double dt = 0.016;
      _tick(dt);
    });
  }

  void _tick(double dt) {
    if (!_isPlaying) {
      return;
    }

    _spawnCooldown -= dt;
    if (_spawnCooldown <= 0) {
      _spawnCooldown = 0.9 + _random.nextDouble() * 0.7;
      _obstacles.add(
        Obstacle(
          lane: _random.nextInt(laneCount),
          y: -0.15,
          type: _random.nextBool() ? ObstacleType.block : ObstacleType.coin,
        ),
      );
    }

    for (final Obstacle obstacle in _obstacles) {
      obstacle.y += obstacleSpeed;
    }

    if (_isJumping) {
      _jumpT += dt;
      if (_jumpT >= jumpDuration) {
        _jumpT = 0;
        _isJumping = false;
      }
    }

    final List<Obstacle> removeList = <Obstacle>[];

    for (final Obstacle obstacle in _obstacles) {
      if (obstacle.y > 1.2) {
        removeList.add(obstacle);
        continue;
      }

      if ((obstacle.y - 0.88).abs() < 0.07 && obstacle.lane == _lane) {
        if (obstacle.type == ObstacleType.coin) {
          _score += 5;
          removeList.add(obstacle);
        } else if (!_isJumping) {
          _gameOver();
          return;
        }
      }
    }

    _obstacles.removeWhere((Obstacle o) => removeList.contains(o));
    _score += 1;

    setState(() {});
  }

  void _gameOver() {
    _timer?.cancel();
    _isPlaying = false;
    _bestScore = max(_bestScore, _score);
    setState(() {});
  }

  void _moveLeft() {
    if (!_isPlaying) return;
    setState(() => _lane = max(0, _lane - 1));
  }

  void _moveRight() {
    if (!_isPlaying) return;
    setState(() => _lane = min(laneCount - 1, _lane + 1));
  }

  void _jump() {
    if (!_isPlaying || _isJumping) return;
    setState(() {
      _isJumping = true;
      _jumpT = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double jumpHeight = _isJumping ? sin(pi * (_jumpT / jumpDuration)) * 0.16 : 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('分数: $_score', style: const TextStyle(fontSize: 20)),
                  Text('最高: $_bestScore', style: const TextStyle(fontSize: 20)),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (DragEndDetails details) {
                  if (details.primaryVelocity == null) return;
                  if (details.primaryVelocity! < 0) {
                    _moveRight();
                  } else {
                    _moveLeft();
                  }
                },
                onTap: _jump,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFF1A1A2E), Color(0xFF16213E)],
                    ),
                  ),
                  child: CustomPaint(
                    painter: SubwayPainter(
                      lane: _lane,
                      obstacles: _obstacles,
                      jumpHeight: jumpHeight,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  FilledButton.tonal(onPressed: _moveLeft, child: const Text('左移')),
                  FilledButton(onPressed: _jump, child: const Text('跳跃')),
                  FilledButton.tonal(onPressed: _moveRight, child: const Text('右移')),
                  FilledButton(
                    onPressed: _isPlaying ? null : _startGame,
                    child: Text(_isPlaying ? '进行中' : '开始游戏'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ObstacleType { block, coin }

class Obstacle {
  Obstacle({required this.lane, required this.y, required this.type});

  int lane;
  double y;
  ObstacleType type;
}

class SubwayPainter extends CustomPainter {
  SubwayPainter({required this.lane, required this.obstacles, required this.jumpHeight});

  final int lane;
  final List<Obstacle> obstacles;
  final double jumpHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint lanePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 2;

    final double laneWidth = size.width / 3;
    for (int i = 1; i < 3; i++) {
      final double x = laneWidth * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), lanePaint);
    }

    for (final Obstacle obstacle in obstacles) {
      final double xCenter = laneWidth * obstacle.lane + laneWidth / 2;
      final double y = obstacle.y * size.height;
      if (obstacle.type == ObstacleType.block) {
        final Rect rect = Rect.fromCenter(center: Offset(xCenter, y), width: 52, height: 38);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          Paint()..color = Colors.redAccent,
        );
      } else {
        canvas.drawCircle(Offset(xCenter, y), 15, Paint()..color = Colors.amber);
      }
    }

    final double playerX = laneWidth * lane + laneWidth / 2;
    final double playerY = size.height * (0.9 - jumpHeight);
    final Rect playerRect = Rect.fromCenter(center: Offset(playerX, playerY), width: 42, height: 56);

    canvas.drawRRect(
      RRect.fromRectAndRadius(playerRect, const Radius.circular(10)),
      Paint()..color = Colors.cyanAccent,
    );

    canvas.drawCircle(
      Offset(playerX, playerRect.top - 10),
      10,
      Paint()..color = Colors.lightBlue.shade100,
    );
  }

  @override
  bool shouldRepaint(covariant SubwayPainter oldDelegate) {
    return oldDelegate.lane != lane ||
        oldDelegate.jumpHeight != jumpHeight ||
        oldDelegate.obstacles != obstacles;
  }
}
