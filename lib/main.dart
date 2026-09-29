import 'dart0convert'; // Будет заменено на 'dart:convert' в коде ниже
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const NbrbRatesApp());
}

class NbrbRatesApp extends StatelessWidget {
  const NbrbRatesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Курсы НБРБ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// Модель данных курса валюты
class Rate {
  final int id;
  final String name;
  final double officialRate;
  final int scale;
  final String code;

  Rate({
    required this.id,
    required this.name,
    required this.officialRate,
    required this.scale,
    required this.code,
  });

  factory Rate.fromJson(Map<String, dynamic> json) {
    return Rate(
      id: json['Cur_ID'] as int,
      name: json['Cur_Name'] as String,
      officialRate: (json['Cur_OfficialRate'] as num).toDouble(),
      scale: json['Cur_Scale'] as int,
      code: json['Cur_Abbreviation'] as String,
    );
  }

  double get unitRate => officialRate / scale;
}

// Главный экран с нижним меню
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime _selectedDate = DateTime.now();
  List<Rate> _allRates = [];
  bool _isLoading = true;
  String _errorMessage = '';

  final List<String> _favoriteCodes = ['USD', 'RUB', 'EUR', 'CNY'];

  @override
  void initState() {
    super.initState();
    _fetchRates(_selectedDate);
  }

  Future<void> _fetchRates(DateTime date) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final formattedDate = DateFormat('yyyy-M-d').format(date);
    final url = Uri.parse('https://nbrb.by/api/exrates/rates?ondate=$formattedDate&periodicity=0');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final rates = data.map((item) => Rate.fromJson(item)).toList();

        setState(() {
          _allRates = rates;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Ошибка сервера: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить данные. Проверьте интернет.';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1996, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 2)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchRates(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? 'Курсы НБРБ' : 'Конвертер валют'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectDate(context),
            tooltip: 'Выбрать дату',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _fetchRates(_selectedDate),
                        child: const Text('Повторить'),
                      )
                    ],
                  ),
                )
              : _currentIndex == 0
                  ? RatesListTab(
                      allRates: _allRates,
                      favoriteCodes: _favoriteCodes,
                      selectedDate: _selectedDate,
                      onDateSelect: () => _selectDate(context),
                    )
                  : ConverterTab(
                      allRates: _allRates,
                      favoriteCodes: _favoriteCodes,
                    ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.currency_exchange),
            label: 'Курсы',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate),
            label: 'Конвертер',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Вкладка 1: Список курсов с блоком Избранного
// -----------------------------------------------------------------------------
class RatesListTab extends StatefulWidget {
  final List<Rate> allRates;
  final List<String> favoriteCodes;
  final DateTime selectedDate;
  final VoidCallback onDateSelect;

  const RatesListTab({
    super.key,
    required this.allRates,
    required this.favoriteCodes,
    required this.selectedDate,
    required this.onDateSelect,
  });

  @override
  State<RatesListTab> createState() => _RatesListTabState();
}

class _RatesListTabState extends State<RatesListTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Rate> _filteredRates = [];

  @override
  void initState() {
    super.initState();
    _filteredRates = List.from(widget.allRates);
  }

  void _filterRates(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredRates = List.from(widget.allRates);
      } else {
        _filteredRates = widget.allRates.where((rate) {
          final q = query.toLowerCase();
          return rate.code.toLowerCase().contains(q) ||
                 rate.name.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy').format(widget.selectedDate);

    final favorites = widget.allRates
        .where((rate) => widget.favoriteCodes.contains(rate.code))
        .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12.0),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Дата: $dateStr',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onDateSelect,
                    icon: const Icon(Icons.edit_calendar, size: 18),
                    label: const Text('Изменить'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Поиск валюты (USD, EUR, RUB)...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
                onChanged: _filterRates,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (_searchController.text.isEmpty && favorites.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '⭐ Избранные валюты',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...favorites.map((rate) => _buildRateCard(rate, isFavorite: true)),
                const Divider(height: 24, thickness: 1),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Все валюты',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              ..._filteredRates.map((rate) => _buildRateCard(rate)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRateCard(Rate rate, {bool isFavorite = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: isFavorite ? 2 : 1,
      color: isFavorite ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            rate.code.substring(0, rate.code.length > 2 ? 2 : rate.code.length),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text('${rate.scale} ${rate.code}'),
        subtitle: Text(rate.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          '${rate.officialRate.toStringAsFixed(4)} BYN',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RateDetailScreen(rate: rate),
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Вкладка 2: Универсальный Мультивалютный Конвертер
// -----------------------------------------------------------------------------
class ConverterTab extends StatefulWidget {
  final List<Rate> allRates;
  final List<String> favoriteCodes;

  const ConverterTab({
    super.key,
    required this.allRates,
    required this.favoriteCodes,
  });

  @override
  State<ConverterTab> createState() => _ConverterTabState();
}

class _ConverterTabState extends State<ConverterTab> {
  final TextEditingController _amountController = TextEditingController(text: '100');
  
  String _fromCode = 'USD';
  String _toCode = 'BYN';
  double _amount = 100;

  @override
  Widget build(BuildContext context) {
    final bynRate = Rate(
      id: 0,
      name: 'Белорусский рубль',
      officialRate: 1.0,
      scale: 1,
      code: 'BYN',
    );

    final List<Rate> converterList = [bynRate, ...widget.allRates];

    final fromRate = converterList.firstWhere((r) => r.code == _fromCode, orElse: () => bynRate);
    final toRate = converterList.firstWhere((r) => r.code == _toCode, orElse: () => bynRate);

    final result = (_amount * fromRate.unitRate) / toRate.unitRate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Конвертация по курсу НБРБ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Сумма для конвертации',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.money),
            ),
            onChanged: (val) {
              setState(() {
                _amount = double.tryParse(val) ?? 0;
              });
            },
          ),
          const SizedBox(height: 20),
          _buildCurrencyDropdown('Из какой валюты:', _fromCode, converterList, (val) {
            if (val != null) setState(() => _fromCode = val);
          }),
          Center(
            child: IconButton.filledTonal(
              icon: const Icon(Icons.swap_vert, size: 28),
              onPressed: () {
                setState(() {
                  final temp = _fromCode;
                  _fromCode = _toCode;
                  _toCode = temp;
                });
              },
              tooltip: 'Поменять местами',
            ),
          ),
          _buildCurrencyDropdown('В какую валюту:', _toCode, converterList, (val) {
            if (val != null) setState(() => _toCode = val);
          }),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text('Результат:', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  FittedBox(
                    child: Text(
                      '${result.toStringAsFixed(2)} $_toCode',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Кросс-курс: 1 $_fromCode = ${(fromRate.unitRate / toRate.unitRate).toStringAsFixed(4)} $_toCode',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdown(
    String label,
    String currentValue,
    List<Rate> list,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: currentValue,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: list.map((rate) {
            final isFav = widget.favoriteCodes.contains(rate.code);
            return DropdownMenuItem<String>(
              value: rate.code,
              child: Text(
                '${isFav ? "⭐ " : ""}${rate.code} — ${rate.name}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Экран детального просмотра валюты и динамики курса
// -----------------------------------------------------------------------------
class RateDetailScreen extends StatefulWidget {
  final Rate rate;

  const RateDetailScreen({super.key, required this.rate});

  @override
  State<RateDetailScreen> createState() => _RateDetailScreenState();
}

class _RateDetailScreenState extends State<RateDetailScreen> {
  List<FlSpot> _chartData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDynamics();
  }

  Future<void> _fetchDynamics() async {
    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 30));

    final startStr = DateFormat('yyyy-M-d').format(startDate);
    final endStr = DateFormat('yyyy-M-d').format(endDate);

    final url = Uri.parse(
        'https://nbrb.by/api/exrates/rates/dynamics/${widget.rate.id}?startDate=$startStr&endDate=$endStr');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<FlSpot> spots = [];

        for (int i = 0; i < data.length; i++) {
          final rateVal = (data[i]['Cur_OfficialRate'] as num).toDouble();
          spots.add(FlSpot(i.toDouble(), rateVal));
        }

        setState(() {
          _chartData = spots;
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.rate.code} - ${widget.rate.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Официальный курс:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      '${widget.rate.scale} ${widget.rate.code} = ${widget.rate.officialRate} BYN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'График изменения курса за 30 дней',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _chartData.isEmpty
                      ? const Center(child: Text('Нет данных для графика'))
                      : LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: const FlTitlesData(
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _chartData,
                                isCurved: true,
                                color: Theme.of(context).colorScheme.primary,
                                barWidth: 3,
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
