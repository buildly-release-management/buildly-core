# Generated by Django 2.2.28 on 2023-01-18 06:51

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0011_auto_20230115_1552'),
    ]

    operations = [
        migrations.RenameField(
            model_name='subscription',
            old_name='stripe_id',
            new_name='customer_stripe_id',
        ),
        migrations.RemoveField(
            model_name='subscription',
            name='stripe_card_info',
        ),
        migrations.AddField(
            model_name='subscription',
            name='stripe_card_id',
            field=models.CharField(blank=True, max_length=255, null=True),
        ),
    ]
