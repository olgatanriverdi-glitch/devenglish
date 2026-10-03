import 'package:flutter/material.dart';

import 'speech.dart';

/// Yuvarlak köşeli, hafif renkli kart.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: color ?? t.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    ),
  );
}

class LevelChip extends StatelessWidget {
  final String level;
  const LevelChip(this.level, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final koyu = t.brightness == Brightness.dark;
    final renk = level.startsWith('A')
        ? Colors.green
        : level.startsWith('B1')
        ? Colors.orange
        : Colors.deepPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level,
        style: t.textTheme.labelSmall?.copyWith(
          color: koyu ? renk.shade200 : renk.shade700,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Metni sesli okuyan küçük düğme. [yavas] true ise yavaş okur.
class SpeakButton extends StatelessWidget {
  final String text;
  final bool? yavas;
  final double size;
  final bool tonal;
  const SpeakButton(
    this.text, {
    super.key,
    this.yavas,
    this.size = 24,
    this.tonal = false,
  });

  @override
  Widget build(BuildContext context) {
    final ikon = Icon(
      yavas == true ? Icons.slow_motion_video : Icons.volume_up_rounded,
      size: size,
    );
    void bas() => Tts.i.speak(text, yavas: yavas);
    return tonal
        ? IconButton.filledTonal(
            onPressed: bas,
            icon: ikon,
            tooltip: yavas == true ? 'Yavaş dinle' : 'Dinle',
          )
        : IconButton(
            onPressed: bas,
            icon: ikon,
            tooltip: yavas == true ? 'Yavaş dinle' : 'Dinle',
          );
  }
}

/// Doğru / yanlış geri bildirimi (alt panel).
class FeedbackBar extends StatelessWidget {
  final bool correct;
  final String title;
  final String? detail;
  final VoidCallback onNext;
  final String nextLabel;
  const FeedbackBar({
    super.key,
    required this.correct,
    required this.title,
    this.detail,
    required this.onNext,
    this.nextLabel = 'Devam',
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final renk = correct ? Colors.green : Colors.red;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(correct ? Icons.check_circle : Icons.cancel, color: renk),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: t.textTheme.titleMedium?.copyWith(
                      color: renk.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail!, style: t.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onNext, child: Text(nextLabel)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yuvarlak ilerleme göstergesi (ortasında metin).
class Ring extends StatelessWidget {
  final double value;
  final String label, sub;
  final double size;
  const Ring({
    super.key,
    required this.value,
    required this.label,
    required this.sub,
    this.size = 110,
  });
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: t.colorScheme.surfaceContainerHighest,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: t.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(sub, style: t.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// Çoktan seçmeli soru kartı: seçenekler, seçim sonrası doğru/yanlış rengi.
class ChoiceList extends StatelessWidget {
  final List<String> options;
  final int? selected;
  final int? correct; // null: henüz cevaplanmadı
  final ValueChanged<int> onSelect;
  const ChoiceList({
    super.key,
    required this.options,
    required this.selected,
    required this.correct,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Builder(
              builder: (_) {
                Color bg = t.colorScheme.surfaceContainerLow;
                Color? border;
                if (correct != null) {
                  if (i == correct) {
                    bg = Colors.green.withValues(alpha: 0.18);
                    border = Colors.green;
                  } else if (i == selected) {
                    bg = Colors.red.withValues(alpha: 0.15);
                    border = Colors.red;
                  }
                } else if (i == selected) {
                  border = t.colorScheme.primary;
                }
                return Material(
                  color: bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: border ?? Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: correct != null ? null : () => onSelect(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              options[i],
                              style: t.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Hedef cümlenin sözcüklerini doğru (yeşil) / eksik (kırmızı) olarak boyar.
class WordChips extends StatelessWidget {
  final List<String> words;
  final List<bool> hit;
  const WordChips({super.key, required this.words, required this.hit});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < words.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (hit[i] ? Colors.green : Colors.red).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              words[i],
              style: t.textTheme.bodyLarge?.copyWith(
                color: hit[i] ? Colors.green.shade800 : Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

void snack(BuildContext c, String m) => ScaffoldMessenger.of(c)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));
