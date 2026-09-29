import burp.api.montoya.MontoyaApi;
import burp.api.montoya.logging.Logging;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.List;

public class BurpLibraryTest {
    public static void main(String[] args) throws Exception {
        List<String> errors = new ArrayList<>();
        Logging logging = (Logging) Proxy.newProxyInstance(Logging.class.getClassLoader(),
            new Class<?>[]{Logging.class}, (proxy, method, values) -> {
                if (method.getName().equals("logToError")) errors.add(String.valueOf(values[0]));
                return null;
            });
        MontoyaApi api = (MontoyaApi) Proxy.newProxyInstance(MontoyaApi.class.getClassLoader(),
            new Class<?>[]{MontoyaApi.class}, (proxy, method, values) ->
                method.getName().equals("logging") ? logging : null);
        UserAgentFuzzer extension = new UserAgentFuzzer();
        Field apiField = UserAgentFuzzer.class.getDeclaredField("api");
        apiField.setAccessible(true);
        apiField.set(extension, api);
        Method load = UserAgentFuzzer.class.getDeclaredMethod("loadUserAgents");
        load.setAccessible(true);
        load.invoke(extension);
        if (!errors.isEmpty()) throw new AssertionError(errors);
        Field library = UserAgentFuzzer.class.getDeclaredField("allUserAgents");
        library.setAccessible(true);
        List<?> entries = (List<?>) library.get(extension);
        if (entries.size() != 11170) throw new AssertionError("Wrong record count: " + entries.size());
        int ai = 0;
        for (Object entry : entries) {
            Field platform = entry.getClass().getDeclaredField("platform");
            platform.setAccessible(true);
            if (platform.get(entry).equals("ai")) ai++;
        }
        if (ai != 70) throw new AssertionError("Wrong AI count: " + ai);
        System.out.println("Burp bundled JSON: 11170 records, 70 AI entries parsed with Gson.");
    }
}
