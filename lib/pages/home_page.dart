// lib/pages/home_page.dart
// ignore_for_file: invalid_use_of_private_type_in_public_api

import 'package:flutter/material.dart';
import '../dialogs/date_selection_dialog.dart';
import '../services/bible_service.dart';
import '../utils/date_formatter.dart';
import 'package:flutter/foundation.dart';

enum LanguageMode { korean, english, compare }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> sheetNames = ["Old Testament", "New Testament", "Psalms"];
  late PageController _pageController;
  int _currentPage = 0;
  DateTime selectedDate = DateTime.now();
  LanguageMode languageMode = LanguageMode.korean; // 초기 모드는 한국어
  double _fabOpacity = 1.0; // FAB 투명도 상태 변수

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
  }

  void _openDateSelection() async {
    DateTime? newDate = await showDialog<DateTime>(
      context: context,
      builder: (context) => DateSelectionDialog(initialDate: selectedDate),
    );
    if (newDate != null) {
      setState(() {
        selectedDate = newDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String titleText;
    switch (languageMode) {
      case LanguageMode.english:
        titleText = "Today's Bible (${formatToday(selectedDate)})";
        break;
      case LanguageMode.compare:
        titleText = "한영 대조 성경 말씀 (${formatToday(selectedDate)})";
        break;
      case LanguageMode.korean:
        titleText = "오늘의 성경 말씀 (${formatToday(selectedDate)})";
        break;
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: GestureDetector(
          onTap: _openDateSelection,
          child: Text(titleText),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: _currentPage == 0 ? Colors.grey[300] : null,
            ),
            onPressed: _currentPage == 0
                ? null
                : () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward,
              color: _currentPage == sheetNames.length - 1 ? Colors.grey[300] : null,
            ),
            onPressed: _currentPage == sheetNames.length - 1
                ? null
                : () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: sheetNames.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
            _fabOpacity = 1.0; // 페이지 전환 시 FAB opacity 초기화
          });
        },
        itemBuilder: (context, index) {
          String lang;
          if (languageMode == LanguageMode.english) {
            lang = "en";
          } else if (languageMode == LanguageMode.compare) {
            lang = "compare";
          } else {
            lang = "kr";
          }
          return BibleTodaySheet(
            sheetTitle: sheetNames[index],
            selectedDate: selectedDate,
            language: lang,
            onScrollChange: (opacity) {
              setState(() {
                _fabOpacity = opacity;
              });
            },
          );
        },
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _fabOpacity,
        duration: const Duration(milliseconds: 300),
        child: FloatingActionButton(
          onPressed: () {
            setState(() {
              if (languageMode == LanguageMode.korean) {
                languageMode = LanguageMode.english;
              } else if (languageMode == LanguageMode.english) {
                languageMode = LanguageMode.compare;
              } else {
                languageMode = LanguageMode.korean;
              }
            });
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Text(
            languageMode == LanguageMode.korean
                ? "ㄱ"
                : languageMode == LanguageMode.english
                ? "A"
                : "ㄱ/A",
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
          ),
        ),
      ),
    );
  }
}

class BibleTodaySheet extends StatefulWidget {
  final String sheetTitle;
  final DateTime selectedDate;
  final String language; // "kr", "en", "compare"
  final Function(double)? onScrollChange; // 스크롤 변화 콜백

  const BibleTodaySheet({
    super.key,
    required this.sheetTitle,
    required this.selectedDate,
    required this.language,
    this.onScrollChange,
  });

  @override
  _BibleTodaySheetState createState() => _BibleTodaySheetState();
}

class _BibleTodaySheetState extends State<BibleTodaySheet> {
  late Future<Map<String, List<Widget>>> groupedVerseWidgetsFuture;
  final ScrollController _scrollController = ScrollController();
  List<String> chapterKeys = [];
  final Map<String, GlobalKey> lastVerseKeys = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(() {
      double opacity = 1.0;
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        double percent =
            _scrollController.offset / _scrollController.position.maxScrollExtent;
        if (percent >= 0.9) {
          opacity = 1 - ((percent - 0.9) / 0.1);
          opacity = opacity.clamp(0.0, 1.0);
        }
      }
      if (widget.onScrollChange != null) {
        widget.onScrollChange!(opacity);
      }
    });
    // 초기 호출로 현재 스크롤 위치에 맞춰 opacity 업데이트 (일반적으로 0 offset일 때 1.0)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.onScrollChange != null) {
        widget.onScrollChange!(1.0);
      }
    });
  }

  @override
  void didUpdateWidget(covariant BibleTodaySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language ||
        oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.sheetTitle != widget.sheetTitle) {
      _loadData();
    }
  }

  void _loadData() {
    groupedVerseWidgetsFuture = loadGroupedBibleVerseWidgets(
      widget.sheetTitle,
      widget.selectedDate,
      context,
      language: widget.language,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<Widget>>>(
      future: groupedVerseWidgetsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          if (kDebugMode) {
            print("오류 발생: ${snapshot.error}");
          }
          return Center(child: Text("오류가 발생했습니다: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("오늘 읽을 성경 본문이 없습니다."));
        }

        var groupedWidgets = snapshot.data!;
        chapterKeys = groupedWidgets.keys.toList();

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            for (var key in chapterKeys) ...[
              SliverList(
                delegate: SliverChildListDelegate([
                  ...groupedWidgets[key]!,
                  SizedBox(
                    key: lastVerseKeys.putIfAbsent(key, () => GlobalKey()),
                    height: 1,
                  ),
                ]),
              ),
            ],
          ],
        );
      },
    );
  }
}
