import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.imageio.ImageIO;

/**
 * Renders a scannable EAN-13 barcode for every item in {@code database/seed.sql}.
 *
 * <p>Run it with the JDK alone — no build, no dependencies:
 *
 * <pre>
 *   java scripts/GenerateBarcodes.java
 * </pre>
 *
 * <p>Writes one PNG per item into {@code docs/barcodes/}, plus a contact sheet holding all of them,
 * so a reviewer can put the sheet on a second screen and scan straight into the app.
 *
 * <p>The codes are read out of the seed rather than hard-coded here, so the images cannot drift
 * away from what is actually in the database. Every check digit is recomputed and verified before
 * anything is drawn.
 */
public final class GenerateBarcodes {

    // ---------------------------------------------------------------------------------
    // EAN-13 encoding
    // ---------------------------------------------------------------------------------

    /** Odd-parity encoding for the left half. */
    private static final String[] L_CODE = {
            "0001101", "0011001", "0010011", "0111101", "0100011",
            "0110001", "0101111", "0111011", "0110111", "0001011"};

    /** Even-parity encoding for the left half. */
    private static final String[] G_CODE = {
            "0100111", "0110011", "0011011", "0100001", "0011101",
            "0111001", "0000101", "0010001", "0001001", "0010111"};

    /** Encoding for the right half; always even parity. */
    private static final String[] R_CODE = {
            "1110010", "1100110", "1101100", "1000010", "1011100",
            "1001110", "1010000", "1000100", "1001000", "1110100"};

    /**
     * Which of L and G encodes each of the six left-hand digits.
     *
     * <p>This is how EAN-13 fits thirteen digits into twelve digits' worth of bars: the first digit
     * is not drawn at all, it is carried by the parity pattern of the other six.
     */
    private static final String[] PARITY = {
            "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
            "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"};

    // ---------------------------------------------------------------------------------
    // Drawing
    // ---------------------------------------------------------------------------------

    private static final int MODULE_WIDTH = 3;
    private static final int BAR_HEIGHT = 150;
    /** Guard and centre bars run lower than the data bars, as the symbology requires. */
    private static final int GUARD_OVERHANG = 12;
    private static final int QUIET_ZONE_LEFT = 11 * MODULE_WIDTH;
    private static final int QUIET_ZONE_RIGHT = 7 * MODULE_WIDTH;
    private static final int TOP_MARGIN = 34;
    private static final int TEXT_BASELINE_GAP = 16;

    private static final Font DIGIT_FONT = new Font(Font.MONOSPACED, Font.PLAIN, 20);
    private static final Font LABEL_FONT = new Font(Font.SANS_SERIF, Font.PLAIN, 15);
    private static final Font SHEET_TITLE_FONT = new Font(Font.SANS_SERIF, Font.BOLD, 26);

    private record Item(String sku, String barcode, String name) {
    }

    public static void main(String[] args) throws IOException {
        Path repoRoot = Path.of("").toAbsolutePath();
        if (!Files.exists(repoRoot.resolve("database/seed.sql"))) {
            System.err.println("Run this from the repository root: java scripts/GenerateBarcodes.java");
            System.exit(1);
        }

        Path outputDir = repoRoot.resolve("docs/barcodes");
        Files.createDirectories(outputDir);

        List<Item> items = readItems(repoRoot.resolve("database/seed.sql"));
        if (items.isEmpty()) {
            System.err.println("No items found in database/seed.sql");
            System.exit(1);
        }

        for (Item item : items) {
            verifyCheckDigit(item.barcode());
            BufferedImage image = renderBarcode(item);
            Path file = outputDir.resolve(item.sku() + "_" + item.barcode() + ".png");
            ImageIO.write(image, "PNG", file.toFile());
            System.out.printf("%-10s %s  %s%n", item.sku(), item.barcode(), item.name());
        }

        Path sheet = outputDir.resolve("all-barcodes.png");
        ImageIO.write(renderContactSheet(items), "PNG", sheet.toFile());

        System.out.printf("%n%d barcodes written to docs/barcodes/, plus all-barcodes.png%n", items.size());
    }

    // ---------------------------------------------------------------------------------
    // Reading the seed
    // ---------------------------------------------------------------------------------

    /**
     * Pulls (sku, barcode, name) out of the {@code items} INSERT in the seed script.
     *
     * <p>Matching the rows rather than maintaining a second list here is the point: the images and
     * the database cannot disagree.
     */
    private static List<Item> readItems(Path seedFile) throws IOException {
        Pattern row = Pattern.compile(
                "\\(\\s*\\d+,\\s*'([^']+)',\\s*'(\\d{13})',\\s*'((?:[^']|'')*)'");

        List<Item> items = new ArrayList<>();
        for (String line : Files.readAllLines(seedFile)) {
            Matcher matcher = row.matcher(line);
            if (matcher.find()) {
                items.add(new Item(matcher.group(1), matcher.group(2),
                        matcher.group(3).replace("''", "'")));
            }
        }
        return items;
    }

    /** Recomputes the modulo-10 check digit and refuses to draw a code that fails it. */
    private static void verifyCheckDigit(String barcode) {
        int sum = 0;
        for (int i = 0; i < 12; i++) {
            int digit = barcode.charAt(i) - '0';
            sum += (i % 2 == 0) ? digit : digit * 3;
        }
        int expected = (10 - (sum % 10)) % 10;
        int actual = barcode.charAt(12) - '0';
        if (expected != actual) {
            throw new IllegalStateException(
                    "Invalid EAN-13 check digit in " + barcode + ": expected " + expected);
        }
    }

    // ---------------------------------------------------------------------------------
    // Rendering
    // ---------------------------------------------------------------------------------

    /** Expands a 13-digit code into its 95 modules, guards included. */
    private static String toModules(String barcode) {
        String parity = PARITY[barcode.charAt(0) - '0'];
        StringBuilder modules = new StringBuilder(95);

        modules.append("101");
        for (int i = 0; i < 6; i++) {
            int digit = barcode.charAt(i + 1) - '0';
            modules.append(parity.charAt(i) == 'L' ? L_CODE[digit] : G_CODE[digit]);
        }
        modules.append("01010");
        for (int i = 0; i < 6; i++) {
            modules.append(R_CODE[barcode.charAt(i + 7) - '0']);
        }
        modules.append("101");

        return modules.toString();
    }

    private static int barcodeWidth() {
        return QUIET_ZONE_LEFT + (95 * MODULE_WIDTH) + QUIET_ZONE_RIGHT;
    }

    private static int barcodeHeight() {
        return TOP_MARGIN + BAR_HEIGHT + GUARD_OVERHANG + TEXT_BASELINE_GAP + 14;
    }

    private static BufferedImage renderBarcode(Item item) {
        int width = barcodeWidth();
        int height = barcodeHeight();

        BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = image.createGraphics();
        g.setColor(Color.WHITE);
        g.fillRect(0, 0, width, height);
        drawBarcode(g, item, 0, 0, true);
        g.dispose();
        return image;
    }

    /** Draws one symbol, its digits and its label at the given offset. */
    private static void drawBarcode(Graphics2D g, Item item, int offsetX, int offsetY, boolean withLabel) {
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING,
                RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
        g.setStroke(new BasicStroke(0));

        String barcode = item.barcode();
        String modules = toModules(barcode);
        int barsTop = offsetY + TOP_MARGIN;

        if (withLabel) {
            g.setColor(new Color(0x33, 0x33, 0x33));
            g.setFont(LABEL_FONT);
            g.drawString(item.sku() + " — " + item.name(), offsetX + 4, offsetY + 20);
        }

        g.setColor(Color.BLACK);
        for (int i = 0; i < modules.length(); i++) {
            if (modules.charAt(i) != '1') {
                continue;
            }
            // The guard pattern (0-2), the centre pattern (45-49) and the trailing guard (92-94)
            // run lower so the digits sit between them, exactly as a printed EAN-13 does.
            boolean isGuard = i <= 2 || (i >= 45 && i <= 49) || i >= 92;
            int barHeight = BAR_HEIGHT + (isGuard ? GUARD_OVERHANG : 0);
            g.fillRect(offsetX + QUIET_ZONE_LEFT + (i * MODULE_WIDTH), barsTop, MODULE_WIDTH, barHeight);
        }

        g.setFont(DIGIT_FONT);
        int digitsBaseline = barsTop + BAR_HEIGHT + GUARD_OVERHANG + TEXT_BASELINE_GAP;

        // The first digit sits in the left quiet zone: it has no bars of its own.
        g.drawString(barcode.substring(0, 1), offsetX + 2, digitsBaseline);

        int leftGroupX = offsetX + QUIET_ZONE_LEFT + (4 * MODULE_WIDTH);
        g.drawString(spaced(barcode.substring(1, 7)), leftGroupX, digitsBaseline);

        int rightGroupX = offsetX + QUIET_ZONE_LEFT + (51 * MODULE_WIDTH);
        g.drawString(spaced(barcode.substring(7, 13)), rightGroupX, digitsBaseline);
    }

    /** Widens the digit groups so they sit roughly under the bars that encode them. */
    private static String spaced(String digits) {
        StringBuilder spaced = new StringBuilder();
        for (int i = 0; i < digits.length(); i++) {
            if (i > 0) {
                spaced.append(' ');
            }
            spaced.append(digits.charAt(i));
        }
        return spaced.toString();
    }

    /** One page holding every barcode, for scanning off a second screen. */
    private static BufferedImage renderContactSheet(List<Item> items) {
        int columns = 3;
        int rows = (items.size() + columns - 1) / columns;
        int cellWidth = barcodeWidth() + 24;
        int cellHeight = barcodeHeight() + 16;
        int titleHeight = 60;

        int width = columns * cellWidth;
        int height = titleHeight + (rows * cellHeight);

        BufferedImage sheet = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = sheet.createGraphics();
        g.setColor(Color.WHITE);
        g.fillRect(0, 0, width, height);

        g.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING,
                RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
        g.setColor(Color.BLACK);
        g.setFont(SHEET_TITLE_FONT);
        g.drawString("Triosuite Invoices — scannable catalogue", 20, 38);

        for (int index = 0; index < items.size(); index++) {
            int x = (index % columns) * cellWidth + 12;
            int y = titleHeight + ((index / columns) * cellHeight);
            drawBarcode(g, items.get(index), x, y, true);
        }

        g.dispose();
        return sheet;
    }
}
