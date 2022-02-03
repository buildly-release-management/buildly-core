# Generated by Django 2.2.13 on 2022-02-03 05:57

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0003_partner'),
    ]

    operations = [
        migrations.AddField(
            model_name='coreuser',
            name='user_type',
            field=models.CharField(blank=True, choices=[('Developer', 'Developer'), ('Product Team', 'Product Team')], max_length=50, null=True),
        ),
    ]
