import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../app/theme/app_colors.dart';

enum LegalDocument {
  privacy(
    title: 'Privacy Policy',
    assetPath: 'assets/legal/privacy-policy.html',
  ),
  terms(
    title: 'Terms and Conditions',
    assetPath: 'assets/legal/terms-and-conditions.html',
  );

  const LegalDocument({required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  LegalDocument? get linkedDocument => switch (this) {
    LegalDocument.privacy => LegalDocument.terms,
    LegalDocument.terms => LegalDocument.privacy,
  };
}

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late Future<String> _document;

  @override
  void initState() {
    super.initState();
    _document = rootBundle.loadString(widget.document.assetPath);
  }

  @override
  void didUpdateWidget(covariant LegalDocumentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _document = rootBundle.loadString(widget.document.assetPath);
    }
  }

  void _openLinkedDocument() {
    final linkedDocument = widget.document.linkedDocument;
    if (linkedDocument == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: linkedDocument),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.document.title)),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.gradientTop,
            AppColors.gradientMiddle,
            AppColors.gradientBottom,
          ],
        ),
      ),
      child: FutureBuilder<String>(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load ${widget.document.title}. Please try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .12),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: HtmlWidget(
                      snapshot.data!,
                      onTapUrl: (url) {
                        if (url == 'privacy-policy.html' ||
                            url == 'terms-and-conditions.html') {
                          _openLinkedDocument();
                          return true;
                        }
                        return false;
                      },
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Baloo2',
                        fontSize: 16,
                      ),
                      customStylesBuilder: (element) {
                        if (element.localName == 'body') {
                          return {
                            'color': '#FFFFFF',
                            'font-family': 'Baloo2',
                            'font-size': '16px',
                            'line-height': '1.6',
                          };
                        }
                        if (element.localName == 'h1') {
                          return {'color': '#FFC52E', 'font-size': '28px'};
                        }
                        if (element.localName == 'h2') {
                          return {'color': '#32D4F4', 'font-size': '20px'};
                        }
                        if (element.localName == 'a') {
                          return {'color': '#FFC52E'};
                        }
                        if (element.classes.contains('meta')) {
                          return {'color': '#D0D8EF'};
                        }
                        if (element.classes.contains('note')) {
                          return {
                            'color': '#FFFFFF',
                            'background-color': '#183CA4',
                            'padding': '10px',
                          };
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
