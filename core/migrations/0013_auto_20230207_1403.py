# Generated by Django 2.2.28 on 2023-02-07 14:03

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0012_auto_20230118_0651'),
    ]

    operations = [
        migrations.AddField(
            model_name='subscription',
            name='subscription_end_date',
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='subscription',
            name='subscription_start_date',
            field=models.DateField(blank=True, null=True),
        ),
    ]