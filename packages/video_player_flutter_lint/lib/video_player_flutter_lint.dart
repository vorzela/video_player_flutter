import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/avoid_hover_preview_per_list_item.dart';
import 'src/rules/avoid_http_hls_load.dart';
import 'src/rules/avoid_vorzela_player_controller_in_build.dart';
import 'src/rules/prefer_dispose_vorzela_player_controller.dart';

/// Entrypoint for `custom_lint` — must stay `createPlugin` in this library.
PluginBase createPlugin() => _VideoPlayerFlutterLint();

class _VideoPlayerFlutterLint extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const AvoidVorzelaPlayerControllerInBuild(),
        const PreferDisposeVorzelaPlayerController(),
        const AvoidHttpHlsLoad(),
        const AvoidHoverPreviewPerListItem(),
      ];
}
