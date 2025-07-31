# Generated migration for gateway SwaggerVersionHistory BigAutoField
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('gateway', '0001_initial'),
    ]

    operations = [
        migrations.AlterField(
            model_name='swaggerversionhistory',
            name='id',
            field=models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID'),
        ),
    ]
