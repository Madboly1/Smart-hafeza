import 'package:flutter/material.dart';

import '../../../core/theme/bouga_tokens.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BOUGA', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w800)),
              Text('كل اللي يهمك.. في بُؤجة واحدة.',
                  style: TextStyle(fontSize: 11, color: BougaColors.muted)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'الإعدادات',
              onPressed: () {},
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(BougaSpacing.md),
            children: [
              const SizedBox(height: BougaSpacing.lg),
              const Text('مساحتك الخاصة للمحتوى',
                  style: TextStyle(color: BougaColors.mint, fontSize: 13)),
              const SizedBox(height: BougaSpacing.sm),
              const Text(
                'خلي المهم دايمًا\nفي متناول إيدك.',
                style: TextStyle(fontSize: 30, height: 1.35, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: BougaSpacing.sm),
              const Text('اجمع، رتّب، وارجع لكل حاجة وقت ما تحتاجها.',
                  style: TextStyle(color: BougaColors.muted)),
              const SizedBox(height: BougaSpacing.lg),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'دوّر في بُؤجتك...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: BougaSpacing.lg),
              const Row(
                children: [
                  _StatCard(label: 'كل المحفوظات', value: '—'),
                  SizedBox(width: BougaSpacing.sm),
                  _StatCard(label: 'تمت مشاهدتها', value: '—'),
                  SizedBox(width: BougaSpacing.sm),
                  _StatCard(label: 'مجموعاتك', value: '—'),
                ],
              ),
              const SizedBox(height: BougaSpacing.xl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(BougaSpacing.lg),
                  child: Column(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 38, color: BougaColors.mint),
                      const SizedBox(height: BougaSpacing.md),
                      const Text('بُؤجتك الجديدة بتستناك',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: BougaSpacing.xs),
                      const Text(
                        'دي قاعدة Flutter الجديدة. هننقل بياناتك ووظائف التطبيق القديم بأمان قبل استبداله.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: BougaColors.muted, height: 1.7),
                      ),
                      const SizedBox(height: BougaSpacing.md),
                      FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.add_link_rounded),
                        label: const Text('إضافة رابط — قريبًا'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(value, style: const TextStyle(
                  color: BougaColors.mint, fontSize: 21, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center,
                  style: const TextStyle(color: BougaColors.muted, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
