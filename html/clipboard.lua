<!DOCTYPE html>
<html>
<head>
    <title>Clipboard Helper</title>
</head>
<body>
    <textarea id="clipboard" style="position: absolute; left: -9999px;"></textarea>
    <script>
        window.addEventListener('message', function(event) {
            if (event.data.type === 'copyToClipboard') {
                const textarea = document.getElementById('clipboard');
                textarea.value = event.data.text;
                textarea.select();
                document.execCommand('copy');
            }
        });
    </script>
</body>
</html>
