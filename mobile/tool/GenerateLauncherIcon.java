import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.GeneralPath;
import java.awt.geom.Path2D;
import java.awt.geom.RoundRectangle2D;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.imageio.ImageIO;

/**
 * Draws the launcher icon: a receipt on the app's teal, at every Android density.
 *
 * <p>Run it from the {@code mobile} directory with the JDK alone — no build, no dependencies:
 *
 * <pre>
 *   java tool/GenerateLauncherIcon.java
 * </pre>
 *
 * <p>Generating it rather than committing an opaque PNG means the icon can be adjusted by editing
 * the code that draws it, and the geometry below is resolution-independent, so every density is a
 * true render rather than a blurry downscale of one bitmap.
 */
public final class GenerateLauncherIcon {

    /** Matches {@code AppTheme._seed}, so the icon and the app are the same colour. */
    private static final Color TEAL = new Color(0x00, 0x69, 0x6D);
    private static final Color TEAL_DARK = new Color(0x00, 0x4B, 0x4E);
    private static final Color PAPER = new Color(0xFF, 0xFF, 0xFF);

    /** Android's launcher densities, and the pixel size each expects. */
    private static final Map<String, Integer> DENSITIES = new LinkedHashMap<>() {{
        put("mipmap-mdpi", 48);
        put("mipmap-hdpi", 72);
        put("mipmap-xhdpi", 96);
        put("mipmap-xxhdpi", 144);
        put("mipmap-xxxhdpi", 192);
    }};

    public static void main(String[] args) throws IOException {
        Path resources = Path.of("android/app/src/main/res");
        if (!Files.isDirectory(resources)) {
            System.err.println("Run this from the mobile/ directory: java tool/GenerateLauncherIcon.java");
            System.exit(1);
        }

        for (Map.Entry<String, Integer> density : DENSITIES.entrySet()) {
            int size = density.getValue();
            Path file = resources.resolve(density.getKey()).resolve("ic_launcher.png");
            Files.createDirectories(file.getParent());
            ImageIO.write(render(size), "PNG", file.toFile());
            System.out.printf("%-18s %3dx%-3d  %s%n", density.getKey(), size, size, file);
        }

        System.out.println("\nLauncher icon written at " + DENSITIES.size() + " densities.");
    }

    private static BufferedImage render(int size) {
        BufferedImage image = new BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = image.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);

        // Rounded-square background, matching the platform's own icon silhouette.
        double corner = size * 0.22;
        g.setColor(TEAL);
        g.fill(new RoundRectangle2D.Double(0, 0, size, size, corner, corner));

        // A slightly darker band along the bottom gives the flat colour some depth without
        // resorting to a gradient that would band at small sizes.
        g.setColor(TEAL_DARK);
        g.fill(new RoundRectangle2D.Double(0, size * 0.72, size, size * 0.28, corner, corner));
        g.setColor(TEAL);
        g.fill(new RoundRectangle2D.Double(0, size * 0.72, size, size * 0.16, 0, 0));

        drawReceipt(g, size);

        g.dispose();
        return image;
    }

    /** A receipt: a white slip with a torn bottom edge and three ruled lines. */
    private static void drawReceipt(Graphics2D g, int size) {
        double width = size * 0.46;
        double height = size * 0.56;
        double left = (size - width) / 2.0;
        double top = size * 0.20;
        double toothHeight = size * 0.045;
        int teeth = 5;

        GeneralPath slip = new GeneralPath(Path2D.WIND_NON_ZERO);
        slip.moveTo(left, top);
        slip.lineTo(left + width, top);
        slip.lineTo(left + width, top + height - toothHeight);

        // Zigzag along the bottom, right to left, so the shape closes cleanly.
        double toothWidth = width / teeth;
        for (int tooth = 0; tooth < teeth; tooth++) {
            double x = left + width - (tooth * toothWidth);
            slip.lineTo(x - (toothWidth / 2.0), top + height);
            slip.lineTo(x - toothWidth, top + height - toothHeight);
        }
        slip.closePath();

        g.setColor(PAPER);
        g.fill(slip);

        // Three ruled lines, the last one short, the way a total sits under its items.
        g.setColor(TEAL);
        double lineInset = width * 0.16;
        double strokeWidth = Math.max(1.0, size * 0.035);
        g.setStroke(new BasicStroke((float) strokeWidth, BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));

        double[] fractions = {0.26, 0.46, 0.66};
        double[] lengths = {1.0, 1.0, 0.55};
        for (int index = 0; index < fractions.length; index++) {
            double y = top + (height * fractions[index]);
            double lineStart = left + lineInset;
            double lineEnd = lineStart + ((width - (2 * lineInset)) * lengths[index]);
            g.drawLine(
                    (int) Math.round(lineStart),
                    (int) Math.round(y),
                    (int) Math.round(lineEnd),
                    (int) Math.round(y));
        }
    }
}
