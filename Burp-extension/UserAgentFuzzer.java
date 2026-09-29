import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.Strictness;
import com.google.gson.stream.JsonReader;
import java.io.StringReader;
import burp.api.montoya.BurpExtension;
import burp.api.montoya.MontoyaApi;
import burp.api.montoya.core.Registration;
import burp.api.montoya.http.HttpService;
import burp.api.montoya.http.message.HttpRequestResponse;
import burp.api.montoya.http.message.requests.HttpRequest;
import burp.api.montoya.http.message.responses.HttpResponse;
import burp.api.montoya.ui.UserInterface;
import burp.api.montoya.ui.contextmenu.ContextMenuEvent;
import burp.api.montoya.ui.contextmenu.ContextMenuItemsProvider;
import burp.api.montoya.ui.contextmenu.MessageEditorHttpRequestResponse;

import javax.swing.BorderFactory;
import javax.swing.DefaultListModel;
import javax.swing.JButton;
import javax.swing.JCheckBox;
import javax.swing.JFileChooser;
import javax.swing.JLabel;
import javax.swing.JList;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JProgressBar;
import javax.swing.JScrollPane;
import javax.swing.JSpinner;
import javax.swing.JTextArea;
import javax.swing.JTextField;
import javax.swing.ListSelectionModel;
import javax.swing.SpinnerNumberModel;
import javax.swing.SwingUtilities;
import javax.swing.border.TitledBorder;
import java.awt.BorderLayout;
import java.awt.Component;
import java.awt.Dimension;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Insets;
import java.awt.event.ActionEvent;
import java.io.BufferedWriter;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

public class UserAgentFuzzer implements BurpExtension, ContextMenuItemsProvider {

    private static final DateTimeFormatter TIMESTAMP = DateTimeFormatter.ofPattern("uuuu-MM-dd HH:mm:ss", Locale.ROOT);
    private static final DateTimeFormatter FILE_TIMESTAMP = DateTimeFormatter.ofPattern("uuuuMMdd-HHmmss", Locale.ROOT);

    private final ExecutorService executor = Executors.newSingleThreadExecutor(r -> {
        Thread thread = new Thread(r, "user-agent-fuzzer");
        thread.setDaemon(true);
        return thread;
    });

    private final List<UserAgentEntry> allUserAgents = new ArrayList<>();
    private final AtomicBoolean running = new AtomicBoolean(false);

    private MontoyaApi api;
    private Registration tabRegistration;
    private Registration menuRegistration;

    private JPanel mainPanel;
    private JTextField targetField;
    private JSpinner rateSpinner;
    private JSpinner intervalSpinner;
    private JCheckBox uniqCheckBox;
    private JCheckBox allBrowsersCheckBox;
    private JList<String> browserList;
    private javax.swing.JComboBox<String> platformCombo;
    private JButton startButton;
    private final AtomicBoolean cancelled = new AtomicBoolean(false);
    private JButton clearConsoleButton;
    private JTextArea consoleArea;
    private JProgressBar progressBar;
    private JLabel progressLabel;
    private JLabel capturedRequestLabel;

    private HttpRequestResponse capturedRequest;
    private List<String> availableBrowserGroups = Collections.emptyList();
    private List<String> availablePlatforms = Arrays.asList("All", "General", "Mobile", "AI");

    @Override
    public void initialize(MontoyaApi api) {
        this.api = api;
        api.extension().setName("User-Agent Fuzzer");

        loadUserAgents();
        try {
            if (SwingUtilities.isEventDispatchThread()) {
                buildSuiteTab();
            } else {
                SwingUtilities.invokeAndWait(this::buildSuiteTab);
            }
        } catch (Exception ex) {
            api.logging().logToError("User-Agent Fuzzer: failed to initialize UI: " + ex.getMessage());
            shutdown();
            return;
        }
        registerContextMenu();

        api.extension().registerUnloadingHandler(this::shutdown);
        logToConsole("User-Agent Fuzzer ready. Capture a request and send it to this tab to begin.");
    }

    @Override
    public List<Component> provideMenuItems(ContextMenuEvent event) {
        Optional<HttpRequestResponse> requestResponse = extractRequestResponse(event);
        if (!requestResponse.isPresent()) {
            return Collections.emptyList();
        }

        javax.swing.JMenuItem menuItem = new javax.swing.JMenuItem("Send to User-Agent Fuzzer tab");
        menuItem.addActionListener(actionEvent -> requestResponse.ifPresent(this::setCapturedRequest));
        return Collections.singletonList(menuItem);
    }

    private void loadUserAgents() {
        String rawJson = readUserAgentJson();
        if (rawJson == null || rawJson.isEmpty()) {
            api.logging().logToError("User-Agent Fuzzer: user_agents.json missing or empty.");
            return;
        }

        try (JsonReader reader = new JsonReader(new StringReader(rawJson))) {
            reader.setStrictness(Strictness.STRICT);
            JsonArray entries = JsonParser.parseReader(reader).getAsJsonArray();
            if (reader.peek() != com.google.gson.stream.JsonToken.END_DOCUMENT) {
                throw new IllegalArgumentException("Trailing JSON data");
            }
            for (JsonElement element : entries) {
                JsonObject entry = element.getAsJsonObject();
                String userAgent = entry.get("user-agent").getAsString();
                if (userAgent.isEmpty() || userAgent.length() > 8192 ||
                        userAgent.chars().anyMatch(ch -> ch < 32 || ch > 126)) {
                    throw new IllegalArgumentException("Invalid User-Agent header");
                }
                allUserAgents.add(new UserAgentEntry(entry.get("id").getAsString(),
                        entry.get("group").getAsString(),
                        entry.get("platform").getAsString().toLowerCase(Locale.ROOT), userAgent));
            }
        } catch (Exception ex) {
            allUserAgents.clear();
            api.logging().logToError("User-Agent Fuzzer: invalid bundled library: " + ex.getMessage());
        }

        LinkedHashSet<String> groups = new LinkedHashSet<>();
        for (UserAgentEntry entry : allUserAgents) {
            groups.add(entry.group);
        }
        availableBrowserGroups = new ArrayList<>(groups);
        Collections.sort(availableBrowserGroups);
    }

    private void buildSuiteTab() {
        mainPanel = new JPanel(new BorderLayout(10, 10));
        mainPanel.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 10));

        JPanel configPanel = new JPanel(new GridBagLayout());
        configPanel.setBorder(new TitledBorder("Configuration"));
        GridBagConstraints gc = new GridBagConstraints();
        gc.insets = new Insets(5, 5, 5, 5);
        gc.anchor = GridBagConstraints.WEST;
        gc.fill = GridBagConstraints.HORIZONTAL;
        gc.gridx = 0;
        gc.gridy = 0;

        configPanel.add(new JLabel("Target domain:"), gc);
        gc.gridx = 1;
        targetField = new JTextField("", 25);
        targetField.setEditable(false);
        configPanel.add(targetField, gc);

        gc.gridx = 0;
        gc.gridy++;
        configPanel.add(new JLabel("Rate (requests per batch):"), gc);
        gc.gridx = 1;
        rateSpinner = new JSpinner(new SpinnerNumberModel(1, 0, 1000, 1));
        ((JSpinner.DefaultEditor) rateSpinner.getEditor()).getTextField().setColumns(8);
        configPanel.add(rateSpinner, gc);

        gc.gridx = 0;
        gc.gridy++;
        configPanel.add(new JLabel("Time interval between batches (seconds):"), gc);
        gc.gridx = 1;
        intervalSpinner = new JSpinner(new SpinnerNumberModel(2, 0, 3600, 1));
        ((JSpinner.DefaultEditor) intervalSpinner.getEditor()).getTextField().setColumns(8);
        configPanel.add(intervalSpinner, gc);

        gc.gridx = 0;
        gc.gridy++;
        configPanel.add(new JLabel("Platforms:"), gc);
        gc.gridx = 1;
        platformCombo = new javax.swing.JComboBox<>(availablePlatforms.toArray(new String[0]));
        platformCombo.setSelectedIndex(0);
        platformCombo.addActionListener(this::onPlatformChanged);
        configPanel.add(platformCombo, gc);

        gc.gridx = 0;
        gc.gridy++;
        configPanel.add(new JLabel("Browser groups:"), gc);
        gc.gridx = 1;

        DefaultListModel<String> browserModel = new DefaultListModel<>();
        availableBrowserGroups.forEach(browserModel::addElement);
        browserList = new JList<>(browserModel);
        browserList.setVisibleRowCount(8);
        browserList.setSelectionMode(ListSelectionModel.MULTIPLE_INTERVAL_SELECTION);
        browserList.addListSelectionListener(e -> updateUniqAvailability());
        JScrollPane browserScroll = new JScrollPane(browserList);
        browserScroll.setPreferredSize(new Dimension(250, 140));

        configPanel.add(browserScroll, gc);

        gc.gridx = 1;
        gc.gridy++;
        allBrowsersCheckBox = new JCheckBox("Use all browser groups", true);
        allBrowsersCheckBox.addActionListener(e -> onAllBrowsersToggled());
        configPanel.add(allBrowsersCheckBox, gc);
        browserList.setEnabled(false);

        gc.gridx = 0;
        gc.gridy++;
        configPanel.add(new JLabel("Uniq groups only:"), gc);
        gc.gridx = 1;
        uniqCheckBox = new JCheckBox("Process unique browser groups only");
        configPanel.add(uniqCheckBox, gc);

        gc.gridx = 0;
        gc.gridy++;
        gc.gridwidth = 2;
        capturedRequestLabel = new JLabel("Captured request: none");
        capturedRequestLabel.setBorder(BorderFactory.createEmptyBorder(6, 0, 6, 0));
        configPanel.add(capturedRequestLabel, gc);

        gc.gridy++;
        JPanel actionPanel = new JPanel(new BorderLayout(5, 5));
        startButton = new JButton("Start sweep");
        startButton.addActionListener(e -> startSweep());
        startButton.setEnabled(false);
        actionPanel.add(startButton, BorderLayout.WEST);
        JButton stopButton = new JButton("Stop after current request");
        stopButton.addActionListener(e -> cancelled.set(true));
        actionPanel.add(stopButton, BorderLayout.CENTER);

        clearConsoleButton = new JButton("Clear console");
        clearConsoleButton.addActionListener(e -> consoleArea.setText(""));
        actionPanel.add(clearConsoleButton, BorderLayout.EAST);
        configPanel.add(actionPanel, gc);

        gc.gridy++;
        progressBar = new JProgressBar(0, 100);
        progressBar.setStringPainted(true);
        progressLabel = new JLabel("Idle");
        JPanel progressPanel = new JPanel(new BorderLayout(5, 5));
        progressPanel.add(progressBar, BorderLayout.CENTER);
        progressPanel.add(progressLabel, BorderLayout.SOUTH);
        configPanel.add(progressPanel, gc);

        consoleArea = new JTextArea(14, 80);
        consoleArea.setEditable(false);
        consoleArea.setLineWrap(true);
        consoleArea.setWrapStyleWord(true);
        JScrollPane consoleScroll = new JScrollPane(consoleArea);
        consoleScroll.setBorder(new TitledBorder("Console output"));

        mainPanel.add(configPanel, BorderLayout.NORTH);
        mainPanel.add(consoleScroll, BorderLayout.CENTER);

        UserInterface ui = api.userInterface();
        tabRegistration = ui.registerSuiteTab("User-Agent Fuzzer", mainPanel);

        updateUniqAvailability();
        updateStartButtonState();
    }

    private void registerContextMenu() {
        menuRegistration = api.userInterface().registerContextMenuItemsProvider(this);
    }

    private void startSweep() {
        if (capturedRequest == null) {
            JOptionPane.showMessageDialog(mainPanel, "Capture a request and send it to the User-Agent Fuzzer tab first.", "No request", JOptionPane.WARNING_MESSAGE);
            return;
        }

        if (running.get()) {
            JOptionPane.showMessageDialog(mainPanel, "Sweep already in progress.", "Busy", JOptionPane.INFORMATION_MESSAGE);
            return;
        }

        List<UserAgentEntry> toTest = filterUserAgents();
        if (toTest.isEmpty()) {
            JOptionPane.showMessageDialog(mainPanel, "No user agents match the selected criteria.", "Nothing to test", JOptionPane.INFORMATION_MESSAGE);
            return;
        }

        int rate = ((Number) rateSpinner.getValue()).intValue();
        int intervalSeconds = ((Number) intervalSpinner.getValue()).intValue();
        HttpRequest baseRequest = capturedRequest.request();
        if (baseRequest == null) {
            JOptionPane.showMessageDialog(mainPanel, "Captured request has no raw message. Please capture a new request.", "Invalid request", JOptionPane.ERROR_MESSAGE);
            running.set(false);
            setControlsEnabled(true);
            return;
        }
        HttpService baseService = capturedRequest.httpService();
        if (baseService == null) {
            JOptionPane.showMessageDialog(mainPanel, "Captured request has no destination service.");
            return;
        }
        // Never retarget a captured request: it may contain cookies, credentials and a body.
        HttpRequest normalizedBaseRequest = baseRequest;
        final String targetFinal = serviceDescription(baseService);
        int confirmed = JOptionPane.showConfirmDialog(mainPanel,
                "Replay " + toTest.size() + " requests to " + targetFinal +
                "?\nThe original method, credentials and body are retained. This may change server state.",
                "Confirm authorized scope", JOptionPane.OK_CANCEL_OPTION, JOptionPane.WARNING_MESSAGE);
        if (confirmed != JOptionPane.OK_OPTION) return;
        cancelled.set(false);

        running.set(true);
        setControlsEnabled(false);
        progressBar.setValue(0);
        progressBar.setMaximum(toTest.size());
        updateProgressLabel("Starting sweep…");
        logToConsole(String.format(Locale.ROOT, "Starting sweep against %s using %d user-agent strings.", serviceDescription(baseService), toTest.size()));

        executor.submit(() -> runSweep(toTest, normalizedBaseRequest, baseService, rate, intervalSeconds, targetFinal));
    }

    private void runSweep(List<UserAgentEntry> userAgents,
                          HttpRequest baseRequest,
                          HttpService service,
                          int rate,
                          int intervalSeconds,
                          String targetDisplay) {
        long startNanos = System.nanoTime();
        List<SweepRecord> records = new ArrayList<>(userAgents.size());
        Map<Integer, Integer> statusCounts = new LinkedHashMap<>();

        int processedInBatch = 0;

        for (int index = 0; index < userAgents.size(); index++) {
            if (cancelled.get() || Thread.currentThread().isInterrupted()) break;
            UserAgentEntry entry = userAgents.get(index);
            HttpRequest requestWithUa = applyUserAgent(baseRequest, entry.userAgent);

            short statusCode = -1;
            String reason = "No response";
            try {
                HttpRequestResponse response = api.http().sendRequest(requestWithUa.withService(service));
                if (response != null && response.hasResponse()) {
                    HttpResponse httpResponse = response.response();
                    statusCode = httpResponse.statusCode();
                    reason = Optional.ofNullable(httpResponse.reasonPhrase()).orElse("");
                }
            } catch (Exception ex) {
                reason = ex.getMessage();
                logToConsole(String.format(Locale.ROOT, "[%s] Error for group '%s': %s",
                        TIMESTAMP.format(LocalDateTime.now()), entry.group, ex.getMessage()));
            }

            records.add(new SweepRecord(entry, statusCode, reason));
            statusCounts.merge((int) statusCode, 1, Integer::sum);
            int progress = index + 1;
            processedInBatch++;

            final short scFinal = statusCode;
            final String reasonFinal = reason;
            final int progressFinal = progress;
            SwingUtilities.invokeLater(() -> {
                progressBar.setValue(progressFinal);
                updateProgressLabel(String.format(Locale.ROOT, "Processed %d/%d (%d%%)",
                        progressFinal, userAgents.size(), (progressFinal * 100) / userAgents.size()));
                appendConsoleLine(String.format(Locale.ROOT, "[%s] %3d %-40s %s",
                        TIMESTAMP.format(LocalDateTime.now()),
                        scFinal,
                        truncate(entry.group, 40),
                        entry.userAgent));
            });

            boolean shouldPause = rate > 0 && processedInBatch >= rate && progress < userAgents.size();
            if (shouldPause && intervalSeconds > 0) {
                processedInBatch = 0;
                try {
                    Thread.sleep(intervalSeconds * 1000L);
                } catch (InterruptedException interruptedException) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }

        long durationMillis = Duration.ofNanos(System.nanoTime() - startNanos).toMillis();
        SwingUtilities.invokeLater(() -> finishSweep(records, statusCounts, targetDisplay, durationMillis));
    }

    private void finishSweep(List<SweepRecord> records,
                             Map<Integer, Integer> statusCounts,
                             String targetDisplay,
                             long durationMillis) {
        running.set(false);
        setControlsEnabled(true);
        updateProgressLabel("Sweep finished.");

        long successCount = records.stream()
                .filter(record -> record.statusCode >= 200 && record.statusCode < 300)
                .count();
        logToConsole(String.format(Locale.ROOT,
                "Sweep completed: %d success (2xx) out of %d in %.2f seconds.",
                successCount,
                records.size(),
                durationMillis / 1000.0));

        showResultsDialog(records, statusCounts, targetDisplay, durationMillis);
    }

    private void showResultsDialog(List<SweepRecord> records,
                                   Map<Integer, Integer> statusCounts,
                                   String targetDisplay,
                                   long durationMillis) {
        StringBuilder summary = new StringBuilder();
        summary.append(String.format(Locale.ROOT, "Target: %s%n", targetDisplay));
        summary.append(String.format(Locale.ROOT, "Total user-agents tested: %d%n", records.size()));
        summary.append(String.format(Locale.ROOT, "Elapsed time: %.2f seconds%n%n", durationMillis / 1000.0));

        List<Map.Entry<Integer, Integer>> sorted = new ArrayList<>(statusCounts.entrySet());
        sorted.sort(Comparator.comparingInt(Map.Entry::getKey));

        for (Map.Entry<Integer, Integer> entry : sorted) {
            int status = entry.getKey();
            int count = entry.getValue();
            String label = status >= 0 ? Integer.toString(status) : "No response";
            summary.append(String.format(Locale.ROOT, "Status %s -> %d agents%n", label, count));

            records.stream()
                    .filter(record -> record.statusCode == status)
                    .limit(5)
                    .forEach(record -> summary.append(String.format(Locale.ROOT,
                            "   • %s (%s)%n", record.entry.userAgent, record.entry.group)));

            if (count > 5) {
                summary.append("   • …\n");
            }
        }

        JTextArea textArea = new JTextArea(summary.toString(), 20, 70);
        textArea.setEditable(false);
        textArea.setLineWrap(true);
        textArea.setWrapStyleWord(true);

        JScrollPane scrollPane = new JScrollPane(textArea);

        JButton saveButton = new JButton("Save results…");
        saveButton.addActionListener(event -> saveResults(records, targetDisplay));

        JPanel panel = new JPanel(new BorderLayout(10, 10));
        panel.add(scrollPane, BorderLayout.CENTER);
        panel.add(saveButton, BorderLayout.SOUTH);

        JOptionPane.showMessageDialog(mainPanel, panel, "User-Agent sweep results", JOptionPane.INFORMATION_MESSAGE);
    }

    private void saveResults(List<SweepRecord> records, String targetDisplay) {
        JFileChooser chooser = new JFileChooser();
        chooser.setSelectedFile(new File("ua_sweep_" + FILE_TIMESTAMP.format(LocalDateTime.now()) + ".txt"));

        int choice = chooser.showSaveDialog(mainPanel);
        if (choice != JFileChooser.APPROVE_OPTION) {
            return;
        }

        Path path = chooser.getSelectedFile().toPath();
        try (BufferedWriter writer = Files.newBufferedWriter(path, StandardCharsets.UTF_8, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING)) {
            writer.write("Target: " + targetDisplay);
            writer.newLine();
            writer.write("Generated: " + TIMESTAMP.format(LocalDateTime.now()));
            writer.newLine();
            writer.newLine();

            for (SweepRecord record : records) {
                writer.write(String.format(Locale.ROOT,
                        "%3d | %-35s | %s%n",
                        record.statusCode,
                        record.entry.group,
                        record.entry.userAgent));
            }
        } catch (IOException ex) {
            JOptionPane.showMessageDialog(mainPanel,
                    "Failed to save results: " + ex.getMessage(),
                    "Save error",
                    JOptionPane.ERROR_MESSAGE);
        }
    }

    private void setCapturedRequest(HttpRequestResponse requestResponse) {
        if (running.get()) return;
        this.capturedRequest = requestResponse;
        HttpService service = requestResponse.httpService();
        HttpRequest request = requestResponse.request();
        String description = request == null ? "Unknown" :
                String.format("%s %s", request.method(), request.url());

        capturedRequestLabel.setText("Captured request: " + description);
        if (service != null) {
            targetField.setText(serviceDescription(service));
        }
        updateStartButtonState();
        logToConsole("Captured request updated from context menu.");
    }

    private void updateStartButtonState() {
        startButton.setEnabled(capturedRequest != null && !running.get());
    }

    private void onAllBrowsersToggled() {
        boolean useAll = allBrowsersCheckBox.isSelected();
        browserList.clearSelection();
        browserList.setEnabled(!useAll);
        updateUniqAvailability();
    }

    private void onPlatformChanged(ActionEvent event) {
        updateUniqAvailability();
    }

    private void updateUniqAvailability() {
        boolean allowUniq = isUniqAllowed();
        uniqCheckBox.setEnabled(allowUniq);
        if (!allowUniq) {
            uniqCheckBox.setSelected(false);
        }
    }

    private boolean isUniqAllowed() {
        boolean platformSpecific = !platformCombo.getSelectedItem().toString().equalsIgnoreCase("All");
        boolean browserSpecific = !allBrowsersCheckBox.isSelected();
        return !platformSpecific && !browserSpecific;
    }

    private List<UserAgentEntry> filterUserAgents() {
        List<UserAgentEntry> filtered = new ArrayList<>();
        Set<String> selectedBrowsers = new LinkedHashSet<>(browserList.getSelectedValuesList());
        boolean useAllBrowsers = allBrowsersCheckBox.isSelected();
        String platformChoice = platformCombo.getSelectedItem().toString().toLowerCase(Locale.ROOT);

        for (UserAgentEntry entry : allUserAgents) {
            if (!useAllBrowsers && !selectedBrowsers.contains(entry.group)) {
                continue;
            }
            if (!platformChoice.equals("all") && !entry.platform.equalsIgnoreCase(platformChoice)) {
                continue;
            }
            filtered.add(entry);
        }

        if (uniqCheckBox.isSelected()) {
            Map<String, Integer> groupCounts = new LinkedHashMap<>();
            for (UserAgentEntry entry : filtered) {
                groupCounts.merge(entry.group, 1, Integer::sum);
            }
            filtered.removeIf(entry -> groupCounts.getOrDefault(entry.group, 0) > 1);
        }

        return filtered;
    }

    private HttpRequest applyUserAgent(HttpRequest request, String userAgent) {
        HttpRequest updated = request;
        if (updated.hasHeader("User-Agent")) {
            updated = updated.withUpdatedHeader("User-Agent", userAgent);
        } else {
            updated = updated.withAddedHeader("User-Agent", userAgent);
        }
        return updated;
    }

    private Optional<HttpRequestResponse> extractRequestResponse(ContextMenuEvent event) {
        List<HttpRequestResponse> selected = event.selectedRequestResponses();
        if (!selected.isEmpty()) {
            return Optional.of(selected.get(0));
        }

        Optional<MessageEditorHttpRequestResponse> editor = event.messageEditorRequestResponse();
        if (editor.isPresent()) {
            return Optional.of(editor.get().requestResponse());
        }

        return Optional.empty();
    }

    private void setControlsEnabled(boolean enabled) {
        targetField.setEnabled(enabled);
        rateSpinner.setEnabled(enabled);
        intervalSpinner.setEnabled(enabled);
        platformCombo.setEnabled(enabled);
        allBrowsersCheckBox.setEnabled(enabled);
        browserList.setEnabled(enabled && !allBrowsersCheckBox.isSelected());
        boolean allowUniq = isUniqAllowed();
        uniqCheckBox.setEnabled(enabled && allowUniq);
        if (!allowUniq) {
            uniqCheckBox.setSelected(false);
        }
        clearConsoleButton.setEnabled(!running.get());
        updateStartButtonState();
    }

    private void updateProgressLabel(String text) {
        progressLabel.setText(text);
    }

    private void appendConsoleLine(String message) {
        consoleArea.append(message);
        consoleArea.append(System.lineSeparator());
        consoleArea.setCaretPosition(consoleArea.getDocument().getLength());
    }

    private void logToConsole(String message) {
        if (!SwingUtilities.isEventDispatchThread()) {
            SwingUtilities.invokeLater(() -> logToConsole(message));
            return;
        }
        appendConsoleLine("[" + TIMESTAMP.format(LocalDateTime.now()) + "] " + message);
    }

    private String truncate(String value, int max) {
        if (value.length() <= max) {
            return value;
        }
        return value.substring(0, Math.max(0, max - 1)) + "…";
    }

    private String serviceDescription(HttpService service) {
        if (service == null) {
            return "unknown host";
        }
        return (service.secure() ? "https://" : "http://") + service.host() + ":" + service.port();
    }

    private String readUserAgentJson() {
        try (InputStream stream = UserAgentFuzzer.class.getResourceAsStream("/user_agents.json")) {
            if (stream != null) {
                byte[] data = stream.readNBytes(16 * 1024 * 1024 + 1);
                if (data.length > 16 * 1024 * 1024) throw new IOException("Library exceeds 16 MiB");
                return new String(data, StandardCharsets.UTF_8);
            }
        } catch (IOException ex) {
            api.logging().logToError("User-Agent Fuzzer: failed reading bundled user_agents.json (" + ex.getMessage() + ")");
        }

        return null;
    }

    private void shutdown() {
        if (tabRegistration != null) {
            tabRegistration.deregister();
        }
        if (menuRegistration != null) {
            menuRegistration.deregister();
        }
        cancelled.set(true);
        executor.shutdownNow();
    }

    private static final class UserAgentEntry {
        final String id;
        final String group;
        final String platform;
        final String userAgent;

        UserAgentEntry(String id, String group, String platform, String userAgent) {
            this.id = id;
            this.group = group;
            this.platform = platform;
            this.userAgent = userAgent;
        }
    }

    private static final class SweepRecord {
        final UserAgentEntry entry;
        final short statusCode;
        final String reason;

        SweepRecord(UserAgentEntry entry, short statusCode, String reason) {
            this.entry = entry;
            this.statusCode = statusCode;
            this.reason = reason;
        }
    }
}
